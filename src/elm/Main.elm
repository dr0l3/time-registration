port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Error(..))
import Json.Decode as Decode
import Json.Encode as Encode
import Debug
import Html exposing (..)
import Bootstrap.CDN as CDN
import Bootstrap.Grid as Grid
import Bootstrap.Button as Button
import Bootstrap.Table as Table



-- ---------------------------
-- PORTS
-- ---------------------------


--port toJs : String -> Cmd msg

port storeTimeSheet: Encode.Value -> Cmd msg

port requestTimeSheets: Int -> Cmd msg

port showTimeSheets: (Decode.Value -> msg) -> Sub msg

port deleteTimeSheet: String -> Cmd msg

-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { counter : Int
    , serverMessage : String
    , timeSheets : List Timeshet
    , error: Maybe String
    , currentPage : SheetPage
    }

type alias SheetPage =
    { pageNumber: Int
    , timeSheets: List Timeshet
    }

type alias Timeshet = 
    { id : String
    , startTs : Int
    , endTs : Int
    , company: String
    }

subscriptions : Model -> Sub Msg
subscriptions model =
    showTimeSheets (decodeTimeSheetPage >> UpdateTimeSheets)

decodeTimeSheetPage: Decode.Value -> Result Decode.Error SheetPage
decodeTimeSheetPage =
    Decode.decodeValue (Decode.map2 SheetPage 
        (Decode.field "pageNumber" Decode.int)
        (Decode.field "timesheets" (Decode.list (Decode.map4 Timeshet 
            (Decode.field "_id" Decode.string)
            (Decode.field "start" Decode.int)
            (Decode.field "end" Decode.int)
            (Decode.field "company" Decode.string)))))

init : Int -> ( Model, Cmd Msg )
init flags =
    ( { counter = flags, serverMessage = "", timeSheets = [], error = Nothing, currentPage = SheetPage 0 [] }, Cmd.none )



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Inc
    | Set Int
    | TestServer
    | OnServerResponse (Result Http.Error String)
    | SendTimesheet
    | UpdateTimeSheets (Result Decode.Error SheetPage)
    | RefreshTimesheets
    | DeleteTimeSheet String


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Inc ->
            ( add1 model, Cmd.none )

        Set m ->
            ( { model | counter = m }, Cmd.none )

        TestServer ->
            ( model
            , Http.get "/test" (Decode.field "result" Decode.string)
                |> Http.send OnServerResponse
            )

        OnServerResponse res ->
            case res of
                Ok r ->
                    ( { model | serverMessage = r }, Cmd.none )

                Err err ->
                    ( { model | serverMessage = "Error: " ++ httpErrorToString err }, Cmd.none )

        SendTimesheet ->
            (model , storeTimeSheet (Encode.object [("start", Encode.int 1), ("end", Encode.int 2), ("company", Encode.string "mycompany")]))
                
        UpdateTimeSheets result ->
            case result of
                Ok sheetPage ->
                    case sheetPage.timeSheets of 
                        [] ->
                            let
                                pageNumber = Basics.max (model.currentPage.pageNumber - 1) 0
                                updateSheetPage = SheetPage pageNumber model.currentPage.timeSheets
                            in
                                ({model | error = Nothing, currentPage = updateSheetPage}, Cmd.none)
                        _ -> 
                            ({model | error = Nothing, currentPage = sheetPage}, Cmd.none)
                Err err ->
                    ({model | error = Just <| Decode.errorToString err }, Cmd.none)
        RefreshTimesheets ->
            (model, requestTimeSheets <| model.currentPage.pageNumber + 1)
        DeleteTimeSheet id ->
            let
                withRemoveTimesheet = List.filter (\elem -> elem.id /= id ) model.currentPage.timeSheets
                currentPage = SheetPage model.currentPage.pageNumber withRemoveTimesheet
            in
                ({model | currentPage = currentPage}, deleteTimeSheet id)
            


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        BadUrl _ ->
            "BadUrl"

        Timeout ->
            "Timeout"

        NetworkError ->
            "NetworkError"

        BadStatus _ ->
            "BadStatus"

        BadPayload _ _ ->
            "BadPayload"


{-| increments the counter

    add1 5 --> 6

-}
add1 : Model -> Model
add1 model =
    { model | counter = model.counter + 1 }



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    Grid.container []
        [ CDN.stylesheet
        , Grid.row []
            [ Grid.col [] 
                [ div [] [ h1 [] [ text "Time registration for busy consultant" ]] ]
            ]
        , Grid.row []
            [ Grid.col []
                [  Button.button [ Button.primary, Button.attrs [ onClick Inc ]] [text "+ 1"]
                , text <| String.fromInt model.counter
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Button.button [Button.primary, Button.attrs [ onClick TestServer]] [text "ping dev server"]
                , text model.serverMessage
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ Button.button [Button.primary, Button.attrs [ onClick SendTimesheet]] [text "Send timesheet!"]
                , Button.button [Button.primary, Button.attrs [onClick RefreshTimesheets]] [text "Get timesheets!"]
                ]
            ]
        , Grid.row []
            [ Grid.col []
                [ renderTimeSheetTable model ]
            ]
        ]

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
        , tbody = Table.tbody [] (List.map renderTimeSheetRow model.currentPage.timeSheets)
        }

renderTimeSheetRow: Timeshet -> Table.Row Msg
renderTimeSheetRow timesheet = 
    Table.tr []
        [ Table.td [] [ text <| String.fromInt timesheet.startTs]
        , Table.td [] [ text <| String.fromInt timesheet.endTs]
        , Table.td [] [ text timesheet.company]
        , Table.td [] [ Button.button [Button.danger, Button.small, Button.attrs [ onClick <| DeleteTimeSheet timesheet.id]] [text "-"]]
        ]

-- ---------------------------
-- MAIN
-- ---------------------------


main : Program Int Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view =
            \model -> view model
        , subscriptions = subscriptions
        }
