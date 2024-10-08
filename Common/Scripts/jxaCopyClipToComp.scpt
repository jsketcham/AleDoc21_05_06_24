JsOsaDAS1.001.00bplist00�Vscript_	�// to run in Terminal:
// % cd /Users/protools/Desktop/testScripts
// % osascript -l JavaScript jxaRenameLastTrack.scpt foo bar
// use 'Accessibility Inspector' to determine UI hierarchy, names of elements

ObjC.import("Foundation");
  
const args = $.NSProcessInfo.processInfo.arguments;
// from console:
// args[0..3] are filename, "/usr/bin/osascript", "-l", "JavaScript" 
// from osaScript in our program:
// @"/usr/bin/osascript,/Users/protools/Library/Scripts/jxaRenameLastTrack.scpt,foobar"	0x0000600001ebbba0
//console.log("args.count",args.count);	// note 'count', Objective C-like 

var argv = [];
var result = '\t-1\terror\t';	// assume failure

if (args.count > 1){

	var startIndex = args.js[1].js == ('-l') ? 4 : 2;	// assume we are called from the command line

	//console.log('startIndex', startIndex);

	for(let i = startIndex; i < args.count; i++){
		argv.push(ObjC.unwrap(args.objectAtIndex(i)));
	}
}


result = copyClipToComp();

result;

function copyClipToComp(){

  	const app = Application('System Events');
	const pt = app.processes['Pro Tools'];
  
  	if(pt.exists()){
	
  		pt.frontmost = true;
		
				var names = pt.windows.name();
	
		for (let i = 0; i < names.length; i++){
	
			if(names[i].startsWith('Edit:')){
			
				var editWindow = pt.windows[names[i]];
			
				editWindow.actions['AXRaise'].perform();
				
				names = editWindow.groups.name();
				
				// get to bottom track
				while(names.length > 0){
					let last = names.pop();
					if (last.endsWith('Track ')){
					app.keystroke(';');
					}
				}
				app.keystroke('pp');	// up 2 tracks
				
				// trim tool off, selector tool on
				var btn = editWindow.groups["Cursor Tool Cluster"].buttons["Selector tool"];
				btn.click();

				// we are counting on being in the clip and not at the start
				app.keystroke('\t', { using: 'option down' });	// tab to start of clip
				app.keystroke('\t', { using: 'shift down' });	// select clip
				app.keystroke('c', { using: 'command down' });	// copy
				app.keystroke(';');	// down a line
				app.keystroke('v', { using: 'command down' });	// paste
				
				// get rid of leftover if any
				app.keystroke('\t');	// tab to boundary
				app.keystroke('\t', { using: 'shift down' });	// tab to end of previous take
				app.keyCode(51);	// delete 
				app.keystroke('\t', { using: 'option down' });	// tab to start of take
				
				return 0;	// success
				
			}
		}
	}

	return -1;	// failure
}

                              	� jscr  ��ޭ