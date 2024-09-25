JsOsaDAS1.001.00bplist00�Vscript_// to run:
// % cd /Users/protools/Desktop/testScripts
// % osascript -l JavaScript jxaKeyStroke.scpt 01020304

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

	//console.log('startIndex', startIndex);

	for(let i = startIndex; i < args.count; i++){
		argv.push(ObjC.unwrap(args.objectAtIndex(i)));
	}
}

if (argv.length > 0) {
	
	console.log('argv',argv);
	
  	const app = Application('System Events');
	const pt = app.processes['Pro Tools'];
  
  	if(pt){
	
		pt.frontmost = true;
		app.keystroke(argv[0]);
		result = 0;

	}
}

result;
                               jscr  ��ޭ