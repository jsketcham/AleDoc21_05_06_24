JsOsaDAS1.001.00bplist00�Vscript_�// to run in Terminal:
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

//dismissModalDialog();	// dismiss modal dialogs
let title = getSessionTitle();
//let sampleRate = getTotalmixSampleRate();	//getSessionSampleRate();
//console.log('sampleRate', sampleRate);
// we get sample rate from UFX, don't need it here
title// + '\t' + sampleRate;

function getSessionSampleRate(){

const app = Application('System Events');
const pt = app.processes['Pro Tools'];

//console.log('getSessionSampleRate');

//var foo = pt.menuBars[0].menuBarItems["Setup"].menus["Setup"].menuItems["Session"];
//foo.click();
	let texts = "";

	try{
		texts = pt.windows['Session Setup'].groups["Session Format"].staticTexts.name();
	}
	catch(error){
		console.log('error, putting up Session Setup window',error);
		pt.menuBars[0].menuBarItems["Setup"].menus["Setup"].menuItems["Session"].click();
		texts = pt.windows['Session Setup'].groups["Session Format"].staticTexts.name();
	}
		console.log('got format group static texts names', texts[2]);
		
		pt.menuBars[0].menuBarItems["Setup"].menus["Setup"].menuItems["Session"].click();	// close session setup window
		
		return(texts[2]);

}
function getTotalmixSampleRate(){

const app = Application('System Events');
const pt = app.processes['TotalmixFX'];

var names = pt.windows.name();
let splitName = names[0].split(' ');
return splitName[splitName.length - 1];	// 48.0k

}

function getSessionTitle(){

const app = Application('System Events');
const pt = app.processes['Pro Tools'];

//console.log('getSessionTitle');
  	if(pt.exists()){
	
  		//pt.frontmost = true;
		var names = pt.windows.name();
		for (let i = 0; i < names.length; i++){
	
			if(names[i].startsWith('Edit:')){
			let name = names[i].slice(6);
			name = name.trim();
			//console.log('Edit window name:', name);
			return name;
			}
		}
	}
	return "-1";

}

function dismissModalDialog(){

	const app = Application('System Events');
	const pt = app.processes['Pro Tools'];

  	if(pt.exists()){
	
  		pt.frontmost = true;
		
		//for(let i = 0; i < pt.windows.length; i++){
			//console.log(pt.windows[i].name());
			//console.log(pt.windows[i].properties());
			//console.log(pt.windows[i].attributes.name());
			//console.log(pt.windows[i].buttons.name());
		//}
		
		for(let i = 0; i < pt.windows.length; i++){
												
			if(pt.windows[i].buttons.name().includes('Cancel')){
											
				pt.windows[i].buttons['Cancel'].click();
				console.log('did cancel',i);
			}else if(pt.windows[i].buttons.name().includes('OK')){
											
				pt.windows[i].buttons['OK'].click();
				console.log('did cancel',i);
			}	
		}
		return 0;
	}
	return -1;
}


                              �jscr  ��ޭ