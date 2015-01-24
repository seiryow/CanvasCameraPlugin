cordova.define("cordova/plugin/CanvasCamera", function(require, exports, module) {
                              var exec = require('cordova/exec');
                              var CanvasCamera = function(){
                              var _orientation = 'landscape';
                              _orientation = 'portrait';
                              var _obj = null;
                              var _context = null;
                              var _camImage = null;
                              
                              var _x = 0;
                              var _y = 0;
                              var _width = 0;
                              var _height = 0;
                              var descslist=[];
                              var test="abc";
                              var b64="abc";
                              };
                              
                              
                              
                              CanvasCamera.prototype.initialize = function(obob) {
                              var _this = this;
                              // this._obj = obj;
                              
                              // this._context = obj.getContext("2d");
                              
                              this._camImage = new Image();
                              obob.style["-webkit-transform"]="rotate(90deg)";
                              // obob.style.width="124%";
                              // obob.style["margin"]="0 0 0 -12%";
                              this.obob = obob;
                              // this.dbg = dbg;
                              // obob=this._camImage;
                              this._camImage.onload = function() {
                              // _this._context.clearRect(0, 0, _this._width, _this._height);
                              // _this._context.save();
                              // console.log(444);
                              // rotate 90
                              // _this._context.translate(_this._width/2, _this._height/2);
                              // _this._context.rotate((90 - window.orientation)*Math.PI/180);
                              // _this._context.drawImage(_this._camImage, 0, 0, 352, 288,
                              // -_this._height/2, -_this._width/2, _this._height,
                              // _this._width);
                              // _this.obob=_this._camImage;
                              _this.obob.src=_this._camImage.src;
                              // _this.dbg.innerHTML=_this._camImage.src;
                              // debugimg2 = document.getElementById("debugimg2");
                              //  debugimg2.src=this._camImage.src;
                              
                              // _this._context.drawImage(_this._camImage, 0, 0);
                              //
                              // _this._context.restore();
                              };
                              
                              // register orientation change event
                              // window.addEventListener('orientationchange', this.doOrientationChange);
                              // this.doOrientationChange();
                              };
                              
                              
                              CanvasCamera.prototype.start = function(options) {
                              cordova.exec(false, false, "CanvasCamera", "startCapture", [options]);
                              this.descs=[];
                              // setTimeout(function(){
                              // cordova.exec(onsuccess, function(){}, "CanvasCamera", "captureImage", []);
                              //
                              // },1000)
                              
                              };
                              var flg=false;
                              CanvasCamera.prototype.stopCapture = function() {
                              // alert(3);
                              cordova.exec(function(){}, false, "CanvasCamera", "stopCapture", [0]);
                              };
                              
                              CanvasCamera.prototype.capture = function(data,detect) {
                              this._camImage.src = data;
                              if(!flg){
                              // alert(this.test);
                              // al();
                              flg=true;
                              }
                              // console.log(data);
                              };
                              
                              var max=0;
                              
                              var cnt=0;
                              var cnt=0;
                              var descslist=[];
                              
                              CanvasCamera.prototype.getdescslist = function() {
                              console.log("getdescslist "+ "abc");
                              // console.log(descslist[0]);
                              // return descslist[0];
                              foo("abc") ;
                              }
                              CanvasCamera.prototype.detect = function(data) {
                              // console.log(data.length);s
                              // alert(data);
                              // if(max<data.length){
                              // max=data.length;
                              // }
                              descslist[cnt]=data;
                              cnt++;
                              if(cnt==101){
                              //console.log(data);
                              // hist();
                              cnt=0;
                              
                              // max=0;
                              }
                              };
                              
                              
                              CanvasCamera.prototype.base64 = function(data) {
                              this.b64=data;
                              };
                              
                              CanvasCamera.prototype.gb64 = function() {
                              //                              console.log(this.b64);
                              return this.b64  ;
                              };
                              
                              
                              
                              CanvasCamera.prototype.setFlashMode = function(flashMode) {
                              cordova.exec(function(){}, function(){}, "CanvasCamera", "setFlashMode", [flashMode]);
                              };
                              
                              CanvasCamera.prototype.setDeepMode = function(deepMode) {
                              cordova.exec(function(){}, function(){}, "CanvasCamera", "setDeepMode", [deepMode]);
                              };
                              
                              CanvasCamera.prototype.setCameraPosition = function(cameraPosition) {
                              cordova.exec(function(){}, function(){}, "CanvasCamera", "setCameraPosition", [cameraPosition]);
                              };
                              
                              CanvasCamera.prototype.take = function() {
                              cordova.exec(function(){}, function(){}, "CanvasCamera", "setCameraPosition", [cameraPosition]);
                              };
                              CanvasCamera.prototype.doOrientationChange = function() {
                              switch(window.orientation)
                              {
                              case -90:
                              case 90:
                              this._orientation = 'landscape';
                              break;
                              default:
                              this._orientation = 'portrait';
                              break;
                              }
                              
                              var windowWidth = window.innerWidth;
                              var windowHeight = window.innerHeight;
                              var pixelRatio = window.devicePixelRatio || 1; // / get pixel ratio of
                              // device
                              
                              
                              this._obj.width = windowWidth;// * pixelRatio; /// resolution of
                              // canvas
                              this._obj.height = windowHeight;// * pixelRatio;
                              
                              
                              this._obj.style.width = windowWidth + 'px';   // / CSS size of canvas
                              this._obj.style.height = windowHeight + 'px';
                              
                              
                              this._x = 0;
                              this._y = 0;
                              this._width = windowWidth;
                              this._height = windowHeight;
                              };
                              
                              CanvasCamera.prototype.takePicture = function(onsuccess) {
                              cordova.exec(onsuccess, function(){}, "CanvasCamera", "captureImage", []);
                              };
                              
                              var myplugin = new CanvasCamera();
                              module.exports = myplugin;
                              });
               
               var CanvasCamera = cordova.require("cordova/plugin/CanvasCamera");
               
               //alert();
               var DestinationType = {
               DATA_URL : 0,
               FILE_URI : 1
               };
               
               var PictureSourceType = {
               PHOTOLIBRARY : 0,
               CAMERA : 1,
               SAVEDPHOTOALBUM : 2
               };
               
               var EncodingType = {
               JPEG : 0,
               PNG : 1
               };
               
               var CameraPosition = {
               BACK : 0,
               FRONT : 1
               };
               
               var CameraPosition = {
               BACK : 1,
               FRONT : 2
               };
               
               var FlashMode = {
               OFF : 0,
               ON : 1,
               AUTO : 2
               };
               
               var DeepMode = {
               OFF : 0,
               ON : 1,
               AUTO : 2
               };
               
               CanvasCamera.DestinationType = DestinationType;
               CanvasCamera.PictureSourceType = PictureSourceType;
               CanvasCamera.EncodingType = EncodingType;
               CanvasCamera.CameraPosition = CameraPosition;
               CanvasCamera.FlashMode = FlashMode;
               CanvasCamera.DeepMode = DeepMode;
               
               
               // cordova.exec(function(){}, function(){}, "CanvasCamera", "setCentroid",
               // [centroid[0][0]);
               
               cordova.exec(function(){}, function(){}, "CanvasCamera", "setCentroid", [123]);
               module.exports = CanvasCamera;
