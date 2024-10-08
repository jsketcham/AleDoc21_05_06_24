JsOsaDAS1.001.00bplist00�Vscript_ // to run:
// % cd /Users/protools/Desktop/testScripts/
// % osascript -l JavaScript jxaWildSyncSelect.scpt *01:02:03:04

ObjC.import("Foundation");
  
const args = $.NSProcessInfo.processInfo.arguments;
// from console:
// args[0..3] are filename, "/usr/bin/osascript", "-l", "JavaScript" 
// from osaScript in our program:
// @"/usr/bin/osascript,/Users/protools/Library/Scripts/jxaKeyStroke.scpt,*1234\n"	0x0000600001ebbba0
//console.log("args.count",args.count);	// note 'count', Objective C-like
result = -1;	// failure
var argv = [];

if (args.count > 1){

	var startIndex = args.js[1].js == ('-l') ? 4 : 2;	// assume we are called from the command line

	console.log('startIndex', startIndex);

	for(let i = startIndex; i < args.count; i++){
		argv.push(ObjC.unwrap(args.objectAtIndex(i)));
	}
}

//argv = ["01:03:33:17"]
	const app = Application('System Events');
  	const pt = app.processes['Pro Tools'];
	var currentApp = Application.currentApplication();
	currentApp.includeStandardAdditions = true;
  
  	if(pt.exists() && argv.length > 0){
	
  		pt.frontmost = true;
		
		app.keystroke('c', { using: 'command down' });
		
		locate(argv[0]);
		result = 0;
			
		app.keystroke('v', { using: 'command down' });
		app.keystroke('m', { using: 'command down' });
		app.keystroke('\t');	// tab to boundary
		app.keystroke('\t',{ using: 'option down' });	// tab to start of take

	}

result;

function locate(arg){
	
  	const app = Application('System Events');
	const pt = app.processes['Pro Tools'];
  
  	if(pt){
	
		// appropriate pt window has to be raised already
		pt.frontmost = true;	// causes video to hide AleDoc overlay
		
		// Ventura, PT11 Ultimate have to provide * and \r here
	
		app.keystroke('*');	// entry mode
		
		// feet+frames or timecode
		if(arg.includes("+")){
			//console.log('feet+frames');
			let ftFr = arg.split("+");
			app.keystroke(ftFr[0]);	// feet
			app.keyCode(124);		// right arrow
			app.keystroke(ftFr[1]);	// frames
		}else{
			//console.log('timecode');
			app.keystroke(arg);
		}
		app.keystroke('\r');
		

		result = 0;

	}

}

                              6jscr  ��ޭ