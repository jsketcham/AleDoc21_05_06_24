JsOsaDAS1.001.00bplist00�Vscript_P// to run in Terminal:
// % cd /Users/protools/Desktop/testScripts
// % osascript -l JavaScript jxaSetDialog.scpt foo bar
// use 'Accessibility Inspector' to determine UI hierarchy, names of elements

ObjC.import("Foundation");
  
const args = $.NSProcessInfo.processInfo.arguments;
// from console:
// args[0..3] are filename, "/usr/bin/osascript", "-l", "JavaScript" 
// from osaScript in our program:
// @"/usr/bin/osascript,/Users/protools/Library/Scripts/jxaRenameLastTrack.scpt 0 foo bar"	0x0000600001ebbba0
//console.log("args.count",args.count);	// note 'count', Objective C-like 
//

var argv = [];
var result = '\t-1\terror\t';	// assume failure

if (args.count > 1){

	var startIndex = args.js[1].js == ('-l') ? 4 : 2;	// assume we are called from the command line

	//console.log('startIndex', startIndex);

	for(let i = startIndex; i < args.count; i++){
		argv.push(ObjC.unwrap(args.objectAtIndex(i)));
	}
}

	try{
	let newDialog = getDialog('enter cue dialog here')
		console.log
		('getDialog did return')
		result = '\t' + newDialog + '\t' + getProToolsPosition()

	}catch(error){
		result = ""	// error indicator
	}

result;
function getProToolsPosition(){

  	const app = Application('System Events');
	const pt = app.processes['Pro Tools'];
  
  	if(pt.exists()){
  		//pt.frontmost = true;
	
		var names = pt.windows.name();
		console.log(names);
	
		for (let i = 0; i < names.length; i++){
	
			if(names[i].startsWith('Edit:')){
			
				var editWindow = pt.windows[names[i]];
				// how to find things: see /Users/protools/Desktop/testScripts/jxaExamples.scpt
				return editWindow.groups["Counter Display Cluster"].textFields["Main Counter"].value();				
			}
		}
	}
}

function getDialog(oldDialog){
var app = Application.currentApplication()
app.includeStandardAdditions = true
 
var response = app.displayDialog("Add Cue", {
    defaultAnswer: oldDialog,
    withIcon: "note",
    buttons: ["Cancel", "Continue"],
    defaultButton: "Continue"
})
// Result: {"buttonReturned":"Continue", "textReturned":"Jen"}
//app.displayDialog("Hello, " + (response.textReturned) + ".")
return response.textReturned
}                              fjscr  ��ޭ