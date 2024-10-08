JsOsaDAS1.001.00bplist00�Vscript_�// to run in Terminal:
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


result = armLastTrack();

result;

function armLastTrack(){

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
				
				while(names.length > 0){
					var last = names.pop();
					if (last.endsWith('Track ')){
					
					console.log(editWindow.groups[last].buttons.name());
					
					/* buttons
					
						Track Record Enable,TrackInput Monitor,Solo,Mute,Not Frozen, 
					*/
					
						var btn = editWindow.groups[last].buttons['Track Record Enable'];
												
						/* btn attributes
						AXIdentifier,AXEnabled,AXFrame,AXVisibleChildren,AXParent,AXDescription,AXTitleUIElement,AXFocused,AXChildren,AXRole,AXSelectedChildren,AXTopLevelUIElement,AXHelp,AXTitle,AXValue,AXWindow,AXSubrole,AXRoleDescription,AXSize,AXPosition 
						*/
						
						if(btn.value() != "on state"){
						//console.log('performing AXPress action');
							btn.actions['AXPress'].perform();//click();	// both work
						}
						
						return 0;
					}
				}

			}
		}
	}
	
	return -1;

}
                              � jscr  ��ޭ