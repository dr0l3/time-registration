'use strict'
const electron = require('electron')

const app = electron.app // this is our app
const BrowserWindow = electron.BrowserWindow // This is a Module that creates windows  

let mainWindow // saves a global reference to mainWindow so it doesn't get garbage collected

app.on('ready', createWindow) // called when electron has initialized

console.log("SOMTHINT")

// This will create our app window, no surprise there
function createWindow () {
  mainWindow = new BrowserWindow({
    width: 1024, 
    height: 768,
    webPreferences : {
      webSecurity : false
    }
  })

  console.log(__dirname)

  // display the index.html file
  //mainWindow.loadURL(`file://${ __dirname }/src/assets/index.html`)
  mainWindow.loadURL('http://localhost:3000')
  
  // open dev tools by default so we can see any console errors
  mainWindow.webContents.openDevTools()

  mainWindow.on('closed', function () {
    mainWindow = null
  })
}

/* Mac Specific things */

// when you close all the windows on a non-mac OS it quits the app
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') { app.quit() }
})

// if there is no mainWindow it creates one (like when you click the dock icon)
app.on('activate', () => {
  if (mainWindow === null) { createWindow() }
})