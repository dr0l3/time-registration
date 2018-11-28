port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Error(..))
import Task
import Json.Decode as Decode
import Json.Encode as Encode
import Html exposing (..)
import Bootstrap.CDN as CDN
import Bootstrap.Grid as Grid
import Bootstrap.Button as Button
import Bootstrap.Table as Table
import Bootstrap.Modal as Modal
import Bootstrap.Dropdown as Dropdown
import Bootstrap.Form as Form
import Bootstrap.Grid.Col as Col
import Bootstrap.Form.Select as Select
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Date exposing (..)
import Time exposing (..)
import Time.Extra as Time exposing (..)
import DatePicker exposing (DateEvent(..), defaultSettings)
import List.Extra as LE
import Verify as Verify exposing (Validator, verify, validate)
import Maybe.Verify
import Html exposing (Html)
import Iso8601 as IsoUtils
import Maybe.Extra as MBE

-- ---------------------------
-- PORTS
-- ---------------------------


--port toJs : String -> Cmd msg

port storeTimeSheet: Encode.Value -> Cmd msg

port requestTimeSheets: Int -> Cmd msg

port showTimeSheets: (Decode.Value -> msg) -> Sub msg

port deleteTimeSheet: Encode.Value -> Cmd msg

port addCompany: String -> Cmd msg

port requestCompanies: () -> Cmd msg

port receiveCompanies: (Decode.Value -> msg) -> Sub msg

port timePickerOnChange: (Decode.Value -> msg) -> Sub msg

port saveTimesheet: (String -> msg) -> Sub msg

port setDefaultDates: List (Encode.Value) -> Cmd msg

port exportCsv: () -> Cmd msg


-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { error: Maybe String
    , timeZone: Time.Zone
    , currentPage : SheetPage
    , addTimesheetVisible: Modal.Visibility
    , editTimesheetVisible: Modal.Visibility
    , addStartTime : Maybe Posix
    , addEndTime: Maybe Posix
    , addSelectCompany: Maybe String
    , addDate : Date
    , addDatePicker : DatePicker.DatePicker
    , editStartTime: Maybe Posix
    , editEndTime: Maybe Posix
    , editSelectCompany: Maybe String
    , editId : Maybe String
    , companyList: List String
    , addCompanyString: Maybe String
    , currentTime: Posix
    , popupMode: Bool
    }

type alias SheetPage =
    { pageNumber: Int
    , timeSheets: List Timesheet
    }

type alias Timesheet =
    { id : String
    , startTs : Posix
    , endTs : Posix
    , company: String
    }

type alias TimeSheetInput =
    { start : Posix
    , end : Posix
    , company : String
    }

type alias TimeSheetUpdate =
    { start : Posix
    , end : Posix
    , company : String
    , id : String
    }

type TimeSheetWrite = Input TimeSheetInput | Update TimeSheetUpdate

type alias WriteRequest =
    { write: TimeSheetWrite
    , currentPage: Int
    }

type alias TimePicked =
    { timePickerId: String
    , hour : Int
    , minute: Int
    }

type alias TimePickerDefaultDate =
    { timePickerId: String
    , hour: Int
    , minute: Int
    }

attemptUpdate: String -> Msg
attemptUpdate str =
  AttemptSubmitAddTimeSeet

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ showTimeSheets (decodeTimeSheetPage >> UpdateTimeSheets)
        , receiveCompanies (decodeCompanies >> SetCompanyList)
        , timePickerOnChange (decodeTimepickerOnChange >> Timevalue)
        , Time.every (60 * 1000) SetDate
        , saveTimesheet attemptUpdate
        ]

decodeTimepickerOnChange: Decode.Value -> Result Decode.Error TimePicked
decodeTimepickerOnChange =
    Decode.decodeValue (Decode.map3 TimePicked
      (Decode.field "timePicker" Decode.string)
      (Decode.field "hour" Decode.int)
      (Decode.field "minute" Decode.int))

decodeCompanies: Decode.Value -> Result Decode.Error (List String)
decodeCompanies =
  Decode.decodeValue (Decode.list Decode.string)


decodeTimeSheetPage: Decode.Value -> Result Decode.Error SheetPage
decodeTimeSheetPage =
    Decode.decodeValue (Decode.map2 SheetPage
        (Decode.field "pageNumber" Decode.int)
        (Decode.field "timesheets" (Decode.list (Decode.map4 Timesheet
            (Decode.field "_id" Decode.string)
            (Decode.field "start" (Decode.map millisToPosix Decode.int))
            (Decode.field "end" (Decode.map millisToPosix Decode.int))
            (Decode.field "company" Decode.string)))))

init : Bool -> ( Model, Cmd Msg )
init flags =
    let
        ( datePicker, datePickerFx ) = DatePicker.init
    in
        (
            { error = Nothing
            , timeZone = utc
            , currentPage = SheetPage 0 []
            , addTimesheetVisible = Modal.hidden
            , editTimesheetVisible = Modal.hidden
            , addStartTime = Nothing
            , addEndTime = Nothing
            , addSelectCompany = Nothing
            , addDate = Date.fromPosix utc <| millisToPosix 0
            , addDatePicker = datePicker
            , editStartTime = Nothing
            , editEndTime = Nothing
            , editSelectCompany = Nothing
            , editId = Nothing
            , companyList = []
            , addCompanyString = Nothing
            , currentTime = millisToPosix 0
            , popupMode = flags},Cmd.batch [now, Cmd.map AddDatePicker  datePickerFx, Task.perform SetTimeZone Time.here, requestCompanies (), requestTimeSheets 0] )



-- ---------------------------
-- UPDATE
-- ---------------------------
now : Cmd Msg
now =
  Time.now |> Task.perform SetDate

type Msg
    = UpdateTimeSheets (Result Decode.Error SheetPage)
    | DeleteTimeSheet String
    | ShowCreateTimesheetModal
    | CloseTimesheetModal
    | ShowEditTimesheetModal String
    | CloseEditTimesheetModal
    | AddSelectStartTime String
    | AddSelectEndTime String
    | AddSelectCompany String
    | EditSelectStartTime String
    | EditSelectEndTime String
    | EditSelectCompany String
    | AttemptSubmitAddTimeSeet
    | AttemptSubmitEditTimeSeet
    | AddDatePicker DatePicker.Msg
    | SetDate Posix
    | SetTimeZone Time.Zone
    | SetCompanyList (Result Decode.Error (List String))
    | AddCompany
    | UpdateCompanyString String
    | Timevalue (Result Decode.Error TimePicked)
    | NextPage
    | PreviousPage
    | Export


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UpdateTimeSheets result ->
            case result of
                Ok sheetPage ->
                    case sheetPage.timeSheets of
                        [] ->
                            ({model | error = Nothing, currentPage = model.currentPage}, Cmd.none)

                        _ ->
                            ({model | error = Nothing, currentPage = sheetPage}, Cmd.none)
                Err err ->
                    ({model | error = Just <| Decode.errorToString err }, Cmd.none)
        DeleteTimeSheet id ->
            let
                withRemoveTimesheet = List.filter (\elem -> elem.id /= id ) model.currentPage.timeSheets
                currentPage = SheetPage model.currentPage.pageNumber withRemoveTimesheet
            in
                ({model | currentPage = currentPage}, deleteTimeSheet <| deleteRequest id model.currentPage.pageNumber)
        ShowCreateTimesheetModal ->
            ({model | addTimesheetVisible = Modal.shown}, Cmd.none)
        ShowEditTimesheetModal sheetId ->
            let
                startTime = Maybe.map (\timesheet -> timesheet.startTs) <| LE.find (\timesheet -> timesheet.id == sheetId ) model.currentPage.timeSheets
                endTime = Maybe.map (\timesheet -> timesheet.endTs) <| LE.find (\timesheet -> timesheet.id == sheetId ) model.currentPage.timeSheets
                company = Maybe.map (\timesheet -> timesheet.company) <| LE.find (\timesheet -> timesheet.id == sheetId ) model.currentPage.timeSheets
                configure1 = case (startTime, endTime) of
                  (Just sts, Just ets) -> [updateDefautDateEdit sts ets model.timeZone]
                  _ -> []
            in
              ({model | editTimesheetVisible = Modal.shown, editStartTime = startTime, editEndTime = endTime, editSelectCompany = company, editId = Just sheetId}, Cmd.batch configure1)
        CloseEditTimesheetModal ->
            ({model | editTimesheetVisible = Modal.hidden}, Cmd.none)

        CloseTimesheetModal ->
            ({model | addTimesheetVisible = Modal.hidden}, Cmd.none)
        AddSelectStartTime str ->
            let
                (startHour, startMinute) =
                        ( Maybe.withDefault 12 <| Maybe.andThen String.toInt <| LE.getAt 0 <| String.split ":" str
                        , Maybe.withDefault 0 <| Maybe.andThen String.toInt <| LE.getAt 1 <| String.split ":" str
                        )
                startDateTime = Time.Parts (Date.year model.addDate) (Date.month model.addDate) (Date.day model.addDate) startHour startMinute 0 0 |> Time.partsToPosix model.timeZone
            in
                ({model | addStartTime = Just startDateTime}, Cmd.none)
        AddSelectEndTime str ->
            let
                (endHour, endMinute) =
                        ( Maybe.withDefault 13 <| Maybe.andThen String.toInt <| LE.getAt 0 <| String.split ":" str
                        , Maybe.withDefault 0 <| Maybe.andThen String.toInt <| LE.getAt 1 <| String.split ":" str
                        )
                endDateTime = Time.Parts (Date.year model.addDate) (Date.month model.addDate) (Date.day model.addDate) endHour endMinute 0 0 |> Time.partsToPosix model.timeZone
            in
                ({model | addEndTime = Just endDateTime}, Cmd.none)
        AddSelectCompany str ->
            ({model | addSelectCompany = Just str}, Cmd.none)
        EditSelectStartTime str ->
            let
                (startHour, startMinute) =
                        ( Maybe.withDefault 12 <| Maybe.andThen String.toInt <| LE.getAt 0 <| String.split ":" str
                        , Maybe.withDefault 0 <| Maybe.andThen String.toInt <| LE.getAt 1 <| String.split ":" str
                        )
                startDateTime = Time.Parts (Date.year model.addDate) (Date.month model.addDate) (Date.day model.addDate) startHour startMinute 0 0 |> Time.partsToPosix model.timeZone
            in
                ({model | editStartTime = Just startDateTime}, Cmd.none)
        EditSelectEndTime str ->
            let
                (endHour, endMinute) =
                        ( Maybe.withDefault 13 <| Maybe.andThen String.toInt <| LE.getAt 0 <| String.split ":" str
                        , Maybe.withDefault 0 <| Maybe.andThen String.toInt <| LE.getAt 1 <| String.split ":" str
                        )
                endDateTime = Time.Parts (Date.year model.addDate) (Date.month model.addDate) (Date.day model.addDate) endHour endMinute 0 0 |> Time.partsToPosix model.timeZone
            in
                ({model | editStartTime = Just endDateTime}, Cmd.none)
        EditSelectCompany str ->
            ({model | editSelectCompany = Just str}, Cmd.none)
        AttemptSubmitAddTimeSeet ->
            case (validator model) of
                Ok input ->
                    ({model | addTimesheetVisible = Modal.hidden}, storeTimeSheet <| inputToEncodedObject input model.currentPage.pageNumber)
                Err err ->
                    let
                        (errString, errList) =  err
                    in
                        ({ model | error = Just errString }, Cmd.none)
        AttemptSubmitEditTimeSeet ->
            case (validatorEdit model) of
                Ok tsUpdate ->
                    ({model | editTimesheetVisible = Modal.hidden}, storeTimeSheet <| updateToEncodedObject tsUpdate model.currentPage.pageNumber)
                Err err ->
                    let
                        (errString, errList) =  err
                    in
                        ({ model | error = Just errString }, Cmd.none)
        AddDatePicker subMsg ->
            let
                ( newDatePicker, dateEvent ) = DatePicker.update settings subMsg model.addDatePicker

                newDate =
                    case dateEvent of
                        Picked changedDate -> changedDate
                        _ -> model.addDate
            in
            ( { model | addDate = newDate, addDatePicker = newDatePicker}, Cmd.none )
        SetDate date ->
            let
                currentMinute = toMinute model.timeZone date
                offsetFromDefaultEnd = 0 - (modBy 30 currentMinute)
                offsetFromDefaultStart = offsetFromDefaultEnd - 30
                defaultEnd = Time.add Time.Minute offsetFromDefaultEnd model.timeZone date
                defaultStart = Time.add Time.Minute offsetFromDefaultStart model.timeZone date

                modelAddStart = case model.addStartTime of
                    Just posix -> posix
                    Nothing -> defaultStart
                modelAddEnd = case model.addEndTime of
                    Just posix -> posix
                    Nothing -> defaultEnd
            in

              ( {model | addDate = Date.fromPosix model.timeZone date, currentTime = date, addStartTime = Just modelAddStart, addEndTime = Just modelAddEnd}, (updateDefautDate date model.timeZone))
        SetTimeZone zone ->
            (  {model | timeZone = zone}, Cmd.none)
        SetCompanyList result ->
            case result of
              Err error -> ({model | error = Just <| Decode.errorToString error }, Cmd.none)
              Ok list ->
                let
                    selectedCompany = case list of
                        [singleCompany] -> Just singleCompany
                        _ -> case model.addSelectCompany of
                          Just company -> model.addSelectCompany
                          Nothing -> List.head list
                in
                    ( {model | companyList = list, addSelectCompany = selectedCompany}, Cmd.none)
        AddCompany ->
            case model.addCompanyString of
                Just name -> ( {model | addCompanyString = Nothing} , addCompany name)
                Nothing -> (model, Cmd.none)

        UpdateCompanyString string ->
            ( {model | addCompanyString = Just string}, Cmd.none)
        Timevalue result ->
            case result of
              Ok timePicked ->
                case timePicked.timePickerId of
                  "datetimepicker1" ->
                      ({model | addStartTime = Just <| timePickedToPosix timePicked model.addDate model.timeZone}, Cmd.none)
                  "datetimepicker2" ->
                      ({model | addEndTime = Just <| timePickedToPosix timePicked model.addDate  model.timeZone}, Cmd.none)
                  "datetimepicker3" ->
                      ({model | editStartTime = Just <| timePickedToPosix timePicked model.addDate  model.timeZone}, Cmd.none)
                  "datetimepicker4" ->
                      ({model | editEndTime = Just <| timePickedToPosix timePicked model.addDate  model.timeZone}, Cmd.none)
                  other -> (model, Cmd.none)

              Err err ->
                  ({model | error = Just <| Decode.errorToString err}, Cmd.none)
        NextPage ->
            (model, requestTimeSheets <| model.currentPage.pageNumber + 1)
        PreviousPage ->
            (model, requestTimeSheets <| model.currentPage.pageNumber - 1)
        Export ->
            (model, exportCsv ())

updateDefautDate: Posix -> Time.Zone -> Cmd msg
updateDefautDate time tz =
  let
    currentMinute = toMinute tz time
    offsetFromDefaultEnd = 0 - (modBy 30 currentMinute)
    offsetFromDefaultStart = offsetFromDefaultEnd - 30
    defaultEnd = Time.add Time.Minute offsetFromDefaultEnd tz time
    defaultStart = Time.add Time.Minute offsetFromDefaultStart tz time
    startConfig = TimePickerDefaultDate "datetimepicker1" (toHour tz defaultStart) (toMinute tz defaultStart)
    endConfig = TimePickerDefaultDate "datetimepicker2" (toHour tz defaultEnd) (toMinute tz defaultEnd)
    configs = [startConfig, endConfig]
    encoded = List.map timePickerDefaultDateToEncodedObject configs
  in
    setDefaultDates encoded

updateDefautDateEdit: Posix -> Posix -> Time.Zone -> Cmd msg
updateDefautDateEdit starTime endTime tz =
  let
    startConfig = TimePickerDefaultDate "datetimepicker3" (toHour tz starTime) (toMinute tz starTime)
    endConfig = TimePickerDefaultDate "datetimepicker4" (toHour tz endTime) (toMinute tz endTime)
    configs = [startConfig, endConfig]
    encoded = List.map timePickerDefaultDateToEncodedObject configs
  in
    setDefaultDates encoded

timePickerDefaultDateToEncodedObject: TimePickerDefaultDate -> Encode.Value
timePickerDefaultDateToEncodedObject config =
  Encode.object
    [ ("timePickerId", Encode.string config.timePickerId)
    , ("config", Encode.object
        [ ("hour", Encode.int config.hour)
        , ("minute", Encode.int config.minute)
        ]
      )
    ]

deleteRequest: String -> Int -> Encode.Value
deleteRequest id currentPage =
  Encode.object
    [ ("id", Encode.string id)
    , ("currentPage", Encode.int currentPage)
    ]

timePickedToPosix: TimePicked -> Date -> Time.Zone -> Posix
timePickedToPosix timePicked date timeZone =
  Time.Parts (Date.year date) (Date.month date) (Date.day date) timePicked.hour timePicked.minute 0 0 |> Time.partsToPosix timeZone


inputToEncodedObject: TimeSheetInput -> Int -> Encode.Value
inputToEncodedObject input currentPage =
    Encode.object
      [ ("currentPage", Encode.int currentPage)
      , ("payload", Encode.object
        [ ("start", Encode.int  <| Time.posixToMillis input.start)
        , ("end", Encode.int <| Time.posixToMillis input.end)
        , ("company", Encode.string input.company)
        , ("currentPage", Encode.int currentPage)
        ]
        )
      ]

updateToEncodedObject: TimeSheetUpdate -> Int -> Encode.Value
updateToEncodedObject tsUpdate currentPage =
    Encode.object
      [ ("currentPage", Encode.int currentPage)
      , ("payload", Encode.object
        [ ("start", Encode.int  <| Time.posixToMillis tsUpdate.start)
        , ("end", Encode.int <| Time.posixToMillis tsUpdate.end)
        , ("company", Encode.string tsUpdate.company)
        , ("_id", Encode.string tsUpdate.id)
        , ("currentPage", Encode.int currentPage)
        ]
        )
      ]

validator : Validator String Model TimeSheetInput
validator =
    validate TimeSheetInput
        |> verify .addStartTime (Maybe.Verify.isJust "No start time")
        |> verify .addEndTime (Maybe.Verify.isJust "No end time")
        |> verify .addSelectCompany (Maybe.Verify.isJust "No company selected")

validatorEdit : Validator String Model TimeSheetUpdate
validatorEdit =
    validate TimeSheetUpdate
        |> verify .editStartTime (Maybe.Verify.isJust "No start time")
        |> verify .editEndTime (Maybe.Verify.isJust "No end time")
        |> verify .editSelectCompany (Maybe.Verify.isJust "No company selected")
        |> verify .editId (Maybe.Verify.isJust "No id selected")

settings : DatePicker.Settings
settings =
    defaultSettings



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    if model.popupMode then
        renderPopupMode model
    else
        renderRegularMode model

renderRegularMode: Model -> Html Msg
renderRegularMode model =
  Grid.container []
      [ CDN.stylesheet
      , Grid.row []
          [ Grid.col []
              [ div [] [ h1 [] [ text "Time registration for the busy consultant" ]] ]
          ]
      , Grid.row []
          [ Grid.col []
              [ Button.button [Button.primary, Button.attrs [ onClick ShowCreateTimesheetModal]] [text "Create timesheet"]
              , Button.button [Button.primary, Button.attrs [ onClick PreviousPage]] [text "Previous"]
              , Button.button [Button.primary, Button.attrs [ onClick NextPage]] [text "Next"]
              , Button.button [Button.primary, Button.attrs [ onClick Export]] [text "Export"]
              ]
          ]
      , Grid.row []
          [ Grid.col []
              [ renderTimeSheetTable model ]
          ]
      , Grid.row []
          [ Grid.col []
              [ renderAddTimesheetModal model]
          ]
      , Grid.row []
          [ Grid.col []
              [ renderEditTimesheetModal model]
          ]
      ]

renderPopupMode: Model -> Html Msg
renderPopupMode model =
  Grid.container []
      [ CDN.stylesheet
      , Grid.row []
          [ Grid.col [] [div [class "row mt-4"] []] ]
      , Grid.row []
          [ Grid.col [] [renderAddTimesheetForm model]
          ]
      ]

renderAddTimesheetModal: Model -> Html Msg
renderAddTimesheetModal model =
    Modal.config CloseTimesheetModal
        |> Modal.large
        |> Modal.hideOnBackdropClick True
        |> Modal.h3 [] [ text "Create timesheet!"]
        |> Modal.body [] [  renderAddTimesheetForm model ]
        |> Modal.view model.addTimesheetVisible


renderEditTimesheetModal: Model -> Html Msg
renderEditTimesheetModal model =
  Modal.config CloseEditTimesheetModal
        |> Modal.large
        |> Modal.hideOnBackdropClick True
        |> Modal.h3 [] [text "Edit timesheet"]
        |> Modal.body [] [ renderEditTimesheetForm model ]
        |> Modal.view model.editTimesheetVisible

renderAddTimesheetForm: Model -> Html Msg
renderAddTimesheetForm model =
    Form.form []
        [ Form.row []
          [ Form.col []
            [ Input.text [Input.onInput UpdateCompanyString, Input.attrs [placeholder "Write company name"]] ]
          , Form.col []
            [ Button.button [Button.onClick AddCompany] [text "Add company"]]
          ]
        , Form.row []
          [ Form.col [ ]
              [ Form.label [] [text "Pick a time"]
              , DatePicker.view (Just model.addDate) settings model.addDatePicker |> Html.map AddDatePicker
              ]
          ]
        , Form.row []
            [ Form.col [ ]
              [ Form.label [] [text "Start time" ]
              , timePicker "datetimepicker1"
              ]
            , Form.col [ ]
              [ Form.label [] [text "End time" ]
              , timePicker "datetimepicker2"
              ]
            , Form.col [ ]
              [ Form.label [] [text "Company"]
              , Select.select [Select.onChange AddSelectCompany] <| companyNamesAdd model
              ]
            ]
        , Form.row []
          [ Form.col []
            [ Form.label [] []
            , Button.button [Button.primary, Button.small, Button.onClick AttemptSubmitAddTimeSeet ] [text "Send"]
            ]
          ]
        ]

renderEditTimesheetForm: Model -> Html Msg
renderEditTimesheetForm model =
    Form.form []
        [ Form.row []
            [ Form.col [ ]
              [ Form.label [] [text "Start time" ]
              , timePicker "datetimepicker3"
              ]
            , Form.col [ ]
              [ Form.label [] [text "End time" ]
              , timePicker "datetimepicker4"
              ]
            , Form.col [ ]
              [ Form.label [] [text "Company"]
              , Select.select [Select.onChange EditSelectCompany] <| companyNamesEdit model
              ]
            ]
        , Form.row []
          [ Form.col []
            [ Form.label [] []
            , Button.button [Button.primary, Button.small, Button.onClick AttemptSubmitEditTimeSeet ] [text "Send"]
            ]
          ]
        ]

timePicker: String -> Html msg
timePicker elementId =
  Html.div [ class "input-group date", id elementId, attribute "data-target-input" "nearest"]
    [ Html.input [ class "form-control datetimepicker-input", attribute "data-target" <| "#" ++ elementId] []
    ,  Html.div [class "input-group-append", attribute "data-target" <| "#" ++ elementId, attribute "data-toggle" "datetimepicker"]
      [ Html.div [class "input-group-text"]
          [
            Html.i [class "fa fa-calendar"][]
          ]
      ]
    ]

companyNamesAdd: Model -> List (Select.Item msg)
companyNamesAdd model =
  List.map (\companyName -> Select.item (if selectedAdd companyName model then [ attribute "selected" "selected" ] else []) [text companyName]) model.companyList

selectedAdd: String -> Model -> Bool
selectedAdd companyName model =
  Maybe.withDefault False (Maybe.map (\selectedName -> companyName == selectedName) model.addSelectCompany)

companyNamesEdit: Model -> List (Select.Item msg)
companyNamesEdit model =
  List.map (\companyName -> Select.item (if selectedEdit companyName model then [ attribute "selected" "selected" ] else []) [text companyName]) model.companyList

selectedEdit: String -> Model -> Bool
selectedEdit companyName model =
  Maybe.withDefault False (Maybe.map (\selectedName -> companyName == selectedName) model.editSelectCompany)

companySelectItemsEdit: Model -> List (Select.Item msg)
companySelectItemsEdit model =
  let
    remaining = LE.filterNot (\listName -> Maybe.withDefault False (Maybe.map (\maybeName -> listName == maybeName) model.editSelectCompany)) model.companyList
    allCompanyNames = (MBE.toList model.editSelectCompany) ++ remaining
    _ = Debug.log "names" allCompanyNames
  in
    List.map (\companyName -> Select.item [] [text companyName]) allCompanyNames

comparePosixDescending: Posix -> Posix -> Order
comparePosixDescending a b =
  Basics.compare (Time.toMillis utc a) (Time.toMillis utc b)

posixToWallClock: Model -> Posix -> Select.Item msg
posixToWallClock model posix =
  let
      parts = posixToParts model.timeZone posix
      hour = parts.hour
      minute = parts.minute
  in
      Select.item [] [text ((String.fromInt <| hour) ++ ":" ++ (String.fromInt minute)) ]

renderTimeSheetTable: Model -> Html Msg
renderTimeSheetTable model =
    Table.table
        { options = [ ]
        , thead = Table.simpleThead
            [ Table.th [] [ text "Start"]
            , Table.th [] [ text "End"]
            , Table.th [] [ text "Company"]
            , Table.th [] []
            ]
        , tbody = Table.tbody [] (List.map (renderTimeSheetRow model) model.currentPage.timeSheets)
        }

toMonthText : Time.Month -> String
toMonthText month =
  case month of
    Jan -> "Januar"
    Feb -> "Februar"
    Mar -> "March"
    Apr -> "April"
    May -> "May"
    Jun -> "June"
    Jul -> "July"
    Aug -> "August"
    Sep -> "September"
    Oct -> "October"
    Nov -> "November"
    Dec -> "December"

toDayText: Int -> String
toDayText day =
  let
      suffix = case modBy 10 day of
        1 -> "st"
        2 -> "nd"
        3 -> "rd"
        _ -> "th"
  in
      String.fromInt day ++ suffix

toTimeText: Int -> Int -> String
toTimeText hour minute =
  let
      hourText = if hour < 10 then "0" ++ String.fromInt hour else String.fromInt hour
      minuteText = if minute < 10 then "0" ++ String.fromInt minute else String.fromInt minute
  in
      hourText ++ ":" ++ minuteText

toUtcString : Model -> Time.Posix -> String
toUtcString model time =
  (toMonthText <| toMonth model.timeZone time)
  ++
  " "
  ++
  toDayText (toDay model.timeZone time)
  ++
  " "
  ++
  toTimeText (toHour model.timeZone time) (toMinute model.timeZone time)

renderTimeSheetRow: Model -> Timesheet -> Table.Row Msg
renderTimeSheetRow model timesheet =
    Table.tr []
        [ Table.td [] [ text <| toUtcString model timesheet.startTs]
        , Table.td [] [ text <| toUtcString model timesheet.endTs]
        , Table.td [] [ text timesheet.company]
        , Table.td []
          [ Button.button [Button.secondary, Button.small, Button.attrs [ onClick <| ShowEditTimesheetModal timesheet.id]] [text "Edit"]
          , Button.button [Button.danger, Button.small, Button.attrs [ onClick <| DeleteTimeSheet timesheet.id]] [text "-"]
          ]
        ]

-- ---------------------------
-- MAIN
-- ---------------------------


main : Program Bool Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view =
            \model -> view model
        , subscriptions = subscriptions
        }
