JsOsaDAS1.001.00bplist00�Vscript_�// to run in Terminal:
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

getTotalmixSampleRate();	//getSessionSampleRate();

function getTotalmixSampleRate(){

const app = Application('System Events');
const pt = app.processes['TotalmixFX'];

var names = pt.windows.name();
if(typeof(names[0]) == 'undefined'){
return 'undefined'
}
if(names[0].includes('- 48.0k')){
return '48.0k'
}
if(names[0].includes('- 96.0k')){
return '96.0k'
}
if(names[0].includes('- 192.0k')){
return '192.0k'
}
let splitName = names[0].split(' ');
return splitName[splitName.length - 1];	// 48.0k

}


                              � jscr  ��ޭ