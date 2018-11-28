'use strict'
const electron = require('electron')
const CronJob = require('cron').CronJob;
const {Menu, MenuItem, Tray} = require('electron')
const electronLocalshortcut = require('electron-localshortcut');
const path = require('path')



const app = electron.app // this is our app
const globalShortcut = electron.globalShortcut
const BrowserWindow = electron.BrowserWindow // This is a Module that creates windows

let normalCron = '0 */30 * * * *'
let everysecondCron = '* * * * * * *'
let job = null
let tray = null
let mainWindow // saves a global reference to mainWindow so it doesn't get garbage collected
let popupWindow

const trayMenuTemplate = [
  {
    label: "Open application",
    click: createWindow
  },
  {
    label: "Close",
    click: () => {
      app.quit()
    }
  },
  {
    label: "Stop popup",
    click: () => {
      if(job != null) job.stop()
    }
  },
  {
    label: "Start popup",
    click: () => {
      job = new CronJob(everysecondCron, function() {
        console.log("CRON RUNINING")
      	const d = new Date();

        if(popupWindow == null) {
          popupWindow = new BrowserWindow({
            width: 1024,
            height: 450,
            webPreferences : {
              webSecurity : false
            }
          })

          popupWindow.loadURL(`file://${__dirname}/src/assets/popup/popup.html`)

          popupWindow.on('closed', function () {
            popupWindow = null
          })

          electronLocalshortcut.register(popupWindow, 'Alt+Enter', () => {
            popupWindow.webContents.send('save-timesheet', "Hello");
                console.log('You pressed alt + enter');
          });
        }
      });
      console.log("STARTED CRONS")
      job.start()
    }
  }
]



app.on('ready', () => {
  console.log("About to create tray")
  tray = new Tray(path.join('','/home/drole/projects/elm-electron-time-tracker/src/assets/images/timer2.png'))
  let trayMenu = Menu.buildFromTemplate(trayMenuTemplate)
  tray.setContextMenu(trayMenu)
  console.log("Tray created")
}) // called when electron has initialized

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

  mainWindow.on('closed', function () {
    mainWindow = null
  })

  // Register a 'CommandOrControl+X' shortcut listener.
  // const ret = globalShortcut.register('CommandOrControl+X', () => {
  //   console.log('CommandOrControl+X is pressed')
  // })

  // if (!ret) {
  //   console.log('registration failed')
  // }

  // Check whether a shortcut is registered.
  console.log(globalShortcut.isRegistered('CommandOrControl+K'))


}




/* Mac Specific things */

// when you close all the windows on a non-mac OS it quits the app
app.on('window-all-closed', () => {

})

// if there is no mainWindow it creates one (like when you click the dock icon)
app.on('activate', () => {
  if (mainWindow === null) { createWindow() }
})

app.on('will-quit', () => {
  // Unregister a shortcut.
  globalShortcut.unregister('CommandOrControl+X')

  // Unregister all shortcuts.
  globalShortcut.unregisterAll()
})
