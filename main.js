'use strict'
const electron = require('electron')
const CronJob = require('cron').CronJob;
const {Menu, MenuItem} = require('electron')
const electronLocalshortcut = require('electron-localshortcut');


const app = electron.app // this is our app
const globalShortcut = electron.globalShortcut
const BrowserWindow = electron.BrowserWindow // This is a Module that creates windows

const menu = new Menu()

menu.append(new MenuItem({
  label: 'Print',
  accelerator: 'CmdOrCtrl+P',
  click: () => { console.log('time to print stuff') }
}))


let mainWindow // saves a global reference to mainWindow so it doesn't get garbage collected
let popupWindow

app.on('ready', createWindow) // called when electron has initialized

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

let normalCron = '0 */30 9-17 * * *'
let everysecondCron = '* * * * * * *'
const job = new CronJob(normalCron, function() {
	const d = new Date();
	console.log('Every 30 minutes between 9-17:', d);

  if(popupWindow == null) {
    console.log("LAUCHING POPUP!")
    popupWindow = new BrowserWindow({
      width: 1024,
      height: 768,
      webPreferences : {
        webSecurity : false
      }
    })

    popupWindow.loadURL(`file://${__dirname}/src/assets/popup.html`)

    popupWindow.on('closed', function () {
      popupWindow = null
    })

    electronLocalshortcut.register(popupWindow, 'Alt+Enter', () => {
      popupWindow.webContents.send('save-timesheet', "Hello");
          console.log('You pressed alt + enter');
    });
  }
});
console.log('After job instantiation');
job.start();

/* Mac Specific things */

// when you close all the windows on a non-mac OS it quits the app
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') { app.quit() }
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
