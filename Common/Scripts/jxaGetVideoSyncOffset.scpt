JsOsaDAS1.001.00bplist00�Vscript_e// to run in Terminal:
// % cd /Users/protools/Desktop/testScripts
// % osascript -l JavaScript jxaCutAndPaste.scpt 01020304
//
ObjC.import("Foundation");
  
const args = $.NSProcessInfo.processInfo.arguments;
// from console:
// args[0..3] are filename, "/usr/bin/osascript", "-l", "JavaScript" 
// from osaScript in our program:
// @"/usr/bin/osascript,/Users/protools/Library/Scripts/jxaCutAndPaste.scpt,*1234"	0x0000600001ebbba0
//console.log("args.count",args.count);	// note 'count', Objective C-like
//
var argv = [];
var result = -1;	// assume failure

if (args.count > 1){

	var startIndex = args.js[1].js == ('-l') ? 4 : 2;	// assume we are called from the command line

	//console.log('startIndex', startIndex);

	for(let i = startIndex; i < args.count; i++){
		argv.push(ObjC.unwrap(args.objectAtIndex(i)));
	}
}

getVideoSyncOffset();

function getVideoSyncOffset(){

  	const app = Application('System Events');
	const pt = app.processes['Pro Tools'];
	var currentApp = Application.currentApplication();
	currentApp.includeStandardAdditions = true;
	
	pt.menuBars[0].menuBarItems["Setup"].menus["Setup"].menuItems["Video Sync Offset..."].click();
	
	let title = 'Video Sync Offset'
	let status = waitForDialogWindow(pt,'',true);
	
	if(status == -1){
	
		return -1;
	}
	
	vsoDialog = pt.windows[pt.windows.name().indexOf(title)];
			
	//AXCloseButton
	let cancelButton = vsoDialog.buttons[0];		// by inspection
	let delayInQuarterFrs = vsoDialog.textFields[1].value();	// by inspection, 1/4 frame window
	let delayInMs = vsoDialog.textFields[0].value();			// by inspection, ms window
			
	cancelButton.click();
	return '\t' + delayInQuarterFrs + '\t' + delayInMs;

}
function waitForDialogWindow(pt,title,onOff){

//console.log('title.length',title.length, typeof('title'))

// wait for the presence or absence of the dialog window
// if title length, look for title. Else, look for dialog AXRoleDescription attribute
	for(let i = 0; i < 100; i++){
				
		//console.log('loop count',i);
					
		try{
			if(typeof('title') == 'string' && title.length > 0){
				// case where we have a title to check, don't need to know attrs, just window names
				//console.log(title,pt.windows.name())
				if(onOff == pt.windows.name().includes(title)){
				
					return 0;
				}
			}else{
				// case where we look for a 'dialog' attr, better have only 1 
				//console.log(pt.windows.attributes.name())
				let attrs = pt.windows.attributes['AXRoleDescription'].value();
				//console.log('typeof(attrs)',typeof(attrs));
				if(typeof(attrs) == 'object' && attrs.includes('dialog') == onOff){
				//console.log(attrs,pt.windows.attributes['AXTitle'].value())
				/*
				// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/for...in
					let windows = pt.windows
					for(const window in windows){
						let role = `${windows[window].attributes['AXRoleDescription'].value()}`
						let title = `${windows[window].attributes['AXTitle'].value()}`
						console.log('role:',role,'title:',title)
					}
					*/
					
					return 0;
				}
			}

		}catch(error){
					
			console.log('waitForDialogWindow',i);
		}
									
	}
	return -1;	// failure

}
                              { jscr  ��ޭ