"use strict";

const {styles} = require('./styles.scss');
const {Elm} = require('../elm/Main');
import { ExportToCsv } from 'export-to-csv';

const remote = window.require('electron').remote;
var ipcRenderer = window.require('electron').ipcRenderer;


var node = document.getElementById("elm");
var app = Elm.Main.init({flags: true, node: node});

var Datastore = require('nedb')
  , timesheetStore = new Datastore({ filename: 'example.db',autoload: true})
  , companyStore = new Datastore({ filename: 'example2.db', autoload: true});

/*app.ports.toJs.subscribe(data => {
    console.log(data);
});*/

app.ports.storeTimeSheet.subscribe(data => {
    const payload = data.payload
    const pageNumber = data.currentPage
    console.log(data)
    if(payload._id != null) {
      timesheetStore.update({_id: payload._id}, payload, {},function (err, newDoc){
        console.log("err during insert of timehssets: " + err);
        console.log(newDoc)
        var window = remote.getCurrentWindow();
        window.close();
      })
    } else {
      timesheetStore.insert(payload, function (err, newDoc){
          console.log("err during insert of timehssets: " + err);
          console.log(newDoc)
          var window = remote.getCurrentWindow();
          window.close();
      })
    }
});

// Use ES2015 syntax and let Babel compile it for you
var requestTimesheets = (pageNumber) => {
  console.log("Requesting timesheets")
  timesheetStore.find({}).sort({start: -1}).skip(pageNumber * 10).limit(10).exec(function(err, docs){
      console.log("err during request of timehssets: " + err);
      console.log(docs);
      const result = {"pageNumber": pageNumber, "timesheets": docs}
      app.ports.showTimeSheets.send(result);
  });
}

app.ports.requestTimeSheets.subscribe( pageNumber => {
    requestTimesheets(pageNumber)
});

app.ports.deleteTimeSheet.subscribe( request => {
    console.log("Attempting to delete timesheet with id:" + request);
    const id = request.id
    const pageNumber = request.currentPage
    timesheetStore.remove({_id: id}, {}, function(err, numRemoved){
      requestTimesheets(pageNumber)
    });
})

app.ports.addCompany.subscribe( data => {
  console.log("Inserting company: ", data)
  companyStore.insert({name: data}, function (err, newDoc){
    if(err != null) console.log("err during insertion of company: "  + err)
    companyStore.find({}).exec(function(err, docs){
      const companyNames = docs.map(doc => doc.name)
      app.ports.receiveCompanies.send(companyNames)
    })
  })
})

app.ports.requestCompanies.subscribe( () => {

  companyStore.find({}).exec(function(err, docs){
    const companyNames = docs.map(doc => doc.name)
    app.ports.receiveCompanies.send(companyNames)
  })
})

app.ports.setDefaultDates.subscribe( configs => {
  console.log(configs)
  configs.map(config => {
    const id = "#"+config.timePickerId
    const defaultDate = moment(config.config)
    $(id).datetimepicker({
        format: 'HH:mm',
        stepping: 30,
        defaultDate: defaultDate,
        useCurrent: false,
        buttons: {
          showToday: true,
          showClose: false
        }
      });
    $(id).on("change.datetimepicker", function (e) {
      const hour = e.date.hour()
      const minute = e.date.minute()
      const object = {
        timePicker: config.timePickerId,
        hour: hour,
        minute: minute
      }
      app.ports.timePickerOnChange.send(object)
    });
  });
});

app.ports.exportCsv.subscribe( () =>{
  timesheetStore.find({}).sort({start: -1}).exec(function(err, docs){
    const options = {
      fieldSeparator: ',',
      quoteStrings: '"',
      decimalseparator: '.',
      showLabels: true,
      showTitle: false,
      title: 'My Awesome CSV',
      useBom: true,
      useKeysAsHeaders: true,
      // headers: ['Column 1', 'Column 2', etc...] <-- Won't work with useKeysAsHeaders present!
    };

    const csvExporter = new ExportToCsv(options);

    const data = docs.map(doc => {
      const startTime = moment(doc.start).format('YYYY/MM/DD HH:mm');
      const endTime = moment(doc.end).format('YYYY/MM/DD HH:mm');
      const companyName = doc.company;
      const csvEntry = {
        start: startTime,
        end: endTime,
        company: companyName
      }
      console.log(csvEntry)
      return csvEntry
    });

    console.log(data)

    csvExporter.generateCsv(data);
  });
})

ipcRenderer.on('save-timesheet', function (event,store) {
    console.log(store);
    app.ports.saveTimesheet.send("hello")
});

// Use ES2015 syntax and let Babel compile it for you
var testFn = (inp) => {
    let a = inp + 1;
    return a;
}
