#!/bin/sh
## Find real-path of this script
for i in '' `echo $PATH | tr ":" " "`
do
  [ -f $i/$0 ] && e=$i/$0
done
[ ! -f $e ] && echo "Unable to find this script real path $0" && exit 1
## Find path of vaadin-grid.html
f=vaadin-grid.html
for i in '.' bower_components/vaadin-grid
do
  [ -f $i/$f ] && d=$i
done
[ ! -f $d/$f ] && echo "Unable go find $d/$f" && exit 2
## Find path of vaadin-grid.min.js
m=vaadin-grid.min.js
[ ! -f $d/$m ] && echo "Unable to find $d/$m" && exit 3
## Patch or restore scripts
if [ -f $d/$m.back ]
then
   echo "Configuring $d/$f and $d/$m for normal usage"
   mv $d/$m.back $d/$m
   perl -pi -e 's,\(window._Polymer \|\| Polymer\)\(,Polymer(,' $d/$f
else
   echo "Configuring $d/$f and $d/$m for SDM usage"
   cp $d/$m $d/$m.back
   tail +32 $e > $d/$m
   perl -pi -e 's,Polymer\(,(window._Polymer || Polymer)(,' $d/$f
fi
exit


/**
 * This startup script is used when we run superdevmode from an app server.
 */
(function($wnd, $doc){
  // document.head does not exist in IE8
  var $head = $doc.head || $doc.getElementsByTagName('head')[0];
  // Compute some codeserver urls so as the user does not need bookmarklets
  var hostName = $wnd.location.hostname;
  var serverUrl = 'http://' + hostName + ':9876';
  var module = 'VaadinGrid';
  var nocacheUrl = serverUrl + '/recompile-requester/' + module;

  // Insert the superdevmode nocache script in the first position of the head
  var devModeScript = $doc.createElement('script');
  devModeScript.src = nocacheUrl;

  // Everybody except IE8 does fire an error event
  // This means that we do not detect a non running SDM with IE8.
  if (devModeScript.addEventListener) {
    var callback = function() {
      // Don't show the confirmation dialogue twice (multimodule)
      if (!$wnd.__gwt__sdm__confirmed &&
           (!$wnd.__gwt_sdm__recompiler || !$wnd.__gwt_sdm__recompiler.loaded)) {
        $wnd.__gwt__sdm__confirmed = true;
        if ($wnd.confirm(
            "Couldn't load " +  module + " from Super Dev Mode\n" +
            "server at " + serverUrl + ".\n" +
            "Please make sure this server is ready.\n" +
            "Do you want to try again?")) {
          $wnd.location.reload();
        }
      }
    };
    devModeScript.addEventListener("error", callback, true);
  }

  var injectScriptTag = function(){
    $head.insertBefore(devModeScript, $head.firstElementChild || $head.children[0]);
  };

  if (/loaded|complete/.test($doc.readyState)) {
    injectScriptTag();
  } else {
    //defer app script insertion until the body is ready
    if($wnd.addEventListener){
      $wnd.addEventListener('load', injectScriptTag, false);
    } else{
      $wnd.attachEvent('onload', injectScriptTag);
    }
  }
})(window, document);

function gridLoaded() {
  return window.vaadin && vaadin.elements && vaadin.elements.grid && vaadin.elements.grid.GridElement;
}

if (!gridLoaded()) {
  // This is needed when vaadin-grid.min.js is loaded asynchronously like
  // in SDM. We must guarantee that gwt grid is loaded and exported before
  // Polymer() and HTMLImports.whenReady() are called.
  window._Polymer = function(obj) {

   delete window._Polymer;

   var _done = false;
   // Overwrite whenReady
   var _whenReady = HTMLImports.whenReady;
   HTMLImports.whenReady = function(done) {
     var id = setInterval(function() {
       if (gridLoaded()) {
         clearInterval(id);
         if (!_done) {
           // Run original Polymer
           Polymer(obj);
           _done = true;
           // Restore whenReady
           HTMLImports.whenReady = _whenReady;
         }
         // Run original whenReady
         _whenReady(done);
       }
     }, 3);
   };
   // if HTMLImports.whenReady is never used, we do.
   setTimeout(HTMLImports.whenReady, 3);
  };
}
