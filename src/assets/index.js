"use strict";

const {styles} = require('./styles.scss');
const {Elm} = require('../elm/Main');

var node = document.getElementById("elm");
var app = Elm.Main.init({flags: 6, node: node});

var Datastore = require('nedb')
  , db = new Datastore({ filename: 'example.db',autoload: true});

/*app.ports.toJs.subscribe(data => {
    console.log(data);
});*/

app.ports.storeTimeSheet.subscribe(data => {
    console.log(data)
    db.insert(data, function (err, newDoc){
        console.log("err during insert of timehssets: " + err);
        console.log(newDoc)
    })
});

app.ports.requestTimeSheets.subscribe( pageNumber => {
    console.log("Requesting timesheets")
    db.find({}).sort({start: 1}).skip(pageNumber * 10).limit(10).exec(function(err, docs){
        console.log("err during request of timehssets: " + err);
        console.log(docs);
        const result = {"pageNumber": pageNumber, "timesheets": docs}
        app.ports.showTimeSheets.send(result);
    });
    
});

app.ports.deleteTimeSheet.subscribe( id => {
    console.log("Attempting to delete timesheet with id:" + id);
    db.remove({_id: id});
})


// Use ES2015 syntax and let Babel compile it for you
var testFn = (inp) => {
    let a = inp + 1;
    return a;
}