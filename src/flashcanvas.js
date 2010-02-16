/*
 * FlashCanvas
 *
 * Copyright (c) 2009      Tim Cameron Ryan
 * Copyright (c) 2009-2010 FlashCanvas Project
 * Released under the MIT/X License
 */

// Reference:
//   http://www.whatwg.org/specs/web-apps/current-work/multipage/the-canvas-element.html
//   http://dev.w3.org/html5/spec/the-canvas-element.html

// If the browser does not support HTML5 Canvas
if (!window["CanvasRenderingContext2D"]) {

(function() {

/*
 * Context API
 */

function Lookup(array) {
	for (var i = 0, len = array.length; i < len; i++)
		this[array[i]] = i;
}

var properties = new Lookup([
	// Canvas element
	"toDataURL",

	// CanvasRenderingContext2D
	"save",
	"restore",
	"scale",
	"rotate",
	"translate",
	"transform",
	"setTransform",
	"globalAlpha",
	"globalCompositeOperation",
	"strokeStyle",
	"fillStyle",
	"createLinearGradient",
	"createRadialGradient",
	"createPattern",
	"lineWidth",
	"lineCap",
	"lineJoin",
	"miterLimit",
	"shadowOffsetX",
	"shadowOffsetY",
	"shadowBlur",
	"shadowColor",
	"clearRect",
	"fillRect",
	"strokeRect",
	"beginPath",
	"closePath",
	"moveTo",
	"lineTo",
	"quadraticCurveTo",
	"bezierCurveTo",
	"arcTo",
	"rect",
	"arc",
	"fill",
	"stroke",
	"clip",
	"isPointInPath",
	"font",
	"textAlign",
	"textBaseline",
	"fillText",
	"strokeText",
	"measureText",
	"drawImage",
	"createImageData",
	"getImageData",
	"putImageData",

	// CanvasGradient
	"addColorStop"
]);

// Whether swf is ready for use
var isReady = {};

// Monitor the number of loading files
var lock = {};

function getStyleId(ctx) {
	var canvasId = ctx._canvasId;
	if (!arguments.callee[canvasId]) arguments.callee[canvasId] = 0;
	return arguments.callee[canvasId]++;
}

// canvas context
var CanvasRenderingContext2D = function(canvas, swf) {
	// back-reference to the canvas
	this.canvas = canvas;

	// back-reference to the swf
	this._swf = swf;

	// unique ID of canvas
	this._canvasId = canvas.uniqueID;

	// initialize drawing states
	this._initialize();

	// frame update interval
	var self = this;
	window.setInterval(function() {
		if (lock[self._canvasId] === 0) {
			self._postCommands();
		}
	}, 30);
};

CanvasRenderingContext2D.prototype = {
	/*
	 * state
	 */

	save: function() {
		// push state
		this._stateStack.push({
			globalAlpha: this.globalAlpha,
			globalCompositeOperation: this.globalCompositeOperation,
			strokeStyle: this.strokeStyle,
			fillStyle: this.fillStyle,
			lineWidth: this.lineWidth,
			lineCap: this.lineCap,
			lineJoin: this.lineJoin,
			miterLimit: this.miterLimit,
			shadowOffsetX: this.shadowOffsetX,
			shadowOffsetY: this.shadowOffsetY,
			shadowBlur: this.shadowBlur,
			shadowColor: this.shadowColor,
			font: this.font,
			textAlign: this.textAlign,
			textBaseline: this.textBaseline
		});

		// write all properties
		this._setCompositing();
		this._setShadows();
		this._setStrokeStyle();
		this._setFillStyle();
		this._setLineStyles();
		this._setFontStyles();

		this._queue.push(properties.save);
	},

	restore: function() {
		// pop state
		if (this._stateStack.length > 0) {
			var state = this._stateStack.pop();
			this.globalAlpha = state.globalAlpha;
			this.globalCompositeOperation = state.globalCompositeOperation;
			this.strokeStyle = state.strokeStyle;
			this.fillStyle = state.fillStyle;
			this.lineWidth = state.lineWidth;
			this.lineCap = state.lineCap;
			this.lineJoin = state.lineJoin;
			this.miterLimit = state.miterLimit;
			this.shadowOffsetX = state.shadowOffsetX;
			this.shadowOffsetY = state.shadowOffsetY;
			this.shadowBlur = state.shadowBlur;
			this.shadowColor = state.shadowColor;
			this.font = state.font;
			this.textAlign = state.textAlign;
			this.textBaseline = state.textBaseline;
		}

		this._queue.push(properties.restore);
	},

	/*
	 * transformations
	 */

	scale: function(x, y) {
		this._queue.push(properties.scale, x, y);
	},

	rotate: function(angle) {
		this._queue.push(properties.rotate, angle);
	},

	translate: function(x, y) {
		this._queue.push(properties.translate, x, y);
	},

	transform: function(m11, m12, m21, m22, dx, dy) {
		this._queue.push(properties.transform, m11, m12, m21, m22, dx, dy);
	},

	setTransform: function(m11, m12, m21, m22, dx, dy) {
		this._queue.push(properties.setTransform, m11, m12, m21, m22, dx, dy);
	},

	/*
	 * compositing
	 */

	_setCompositing: function() {
		var queue = this._queue;
		if (this._globalAlpha != this.globalAlpha) {
			this._globalAlpha = this.globalAlpha;
			queue.push(properties.globalAlpha, this.globalAlpha);
		}
		if (this._globalCompositeOperation != this.globalCompositeOperation) {
			this._globalCompositeOperation = this.globalCompositeOperation;
			queue.push(properties.globalCompositeOperation, this.globalCompositeOperation);
		}
	},

	/*
	 * colors and styles
	 */

	_setStrokeStyle: function() {
		if (this._strokeStyle != this.strokeStyle) {
			var style = this._strokeStyle = this.strokeStyle;
			this._queue.push(properties.strokeStyle, (typeof style === "object") ? style.id : style);
		}
	},

	_setFillStyle: function() {
		if (this._fillStyle != this.fillStyle) {
			var style = this._fillStyle = this.fillStyle;
			this._queue.push(properties.fillStyle, (typeof style === "object") ? style.id : style);
		}
	},

	createLinearGradient: function(x0, y0, x1, y1) {
		this._queue.push(properties.createLinearGradient, x0, y0, x1, y1);
		return new CanvasGradient(this);
	},

	createRadialGradient: function(x0, y0, r0, x1, y1, r1) {
		this._queue.push(properties.createRadialGradient, x0, y0, r0, x1, y1, r1);
		return new CanvasGradient(this);
	},

	createPattern: function(image, repetition) {
		// The first argument is HTMLImageElement, HTMLCanvasElement or
		// HTMLVideoElement. For now, only HTMLImageElement is supported.
		if (image.tagName.toUpperCase() !== "IMG") return;

		this._queue.push(properties.createPattern, image.src, repetition);

		if (isReady[this._canvasId]) {
			this._postCommands();
			++lock[this._canvasId];
		}

		return new CanvasPattern(this);
	},

	/*
	 * line caps/joins
	 */

	_setLineStyles: function() {
		var queue = this._queue;
		if ((this._lineWidth != this.lineWidth) && isFinite(this.lineWidth)) {
			this._lineWidth = this.lineWidth;
			queue.push(properties.lineWidth, this.lineWidth);
		}
		if (this._lineCap != this.lineCap) {
			this._lineCap = this.lineCap;
			queue.push(properties.lineCap, this.lineCap);
		}
		if (this._lineJoin != this.lineJoin) {
			this._lineJoin = this.lineJoin;
			queue.push(properties.lineJoin, this.lineJoin);
		}
		if ((this._miterLimit != this.miterLimit) && isFinite(this.miterLimit)) {
			this._miterLimit = this.miterLimit;
			queue.push(properties.miterLimit, this.miterLimit);
		}
	},

	/*
	 * shadows
	 */

	_setShadows: function() {
		var queue = this._queue;
		if (this._shadowOffsetX != this.shadowOffsetX) {
			this._shadowOffsetX = this.shadowOffsetX;
			queue.push(properties.shadowOffsetX, this.shadowOffsetX);
		}
		if (this._shadowOffsetY != this.shadowOffsetY) {
			this._shadowOffsetY = this.shadowOffsetY;
			queue.push(properties.shadowOffsetY, this.shadowOffsetY);
		}
		if (this._shadowBlur != this.shadowBlur) {
			this._shadowBlur = this.shadowBlur;
			queue.push(properties.shadowBlur, this.shadowBlur);
		}
		if (this._shadowColor != this.shadowColor) {
			this._shadowColor = this.shadowColor;
			queue.push(properties.shadowColor, this.shadowColor);
		}
	},

	/*
	 * rects
	 */

	clearRect: function(x, y, w, h) {
		this._queue.push(properties.clearRect, x, y, w, h);
	},

	fillRect: function(x, y, w, h) {
		this._setCompositing();
		this._setShadows();
		this._setFillStyle();
		this._queue.push(properties.fillRect, x, y, w, h);
	},

	strokeRect: function(x, y, w, h) {
		this._setCompositing();
		this._setShadows();
		this._setStrokeStyle();
		this._setLineStyles();
		this._queue.push(properties.strokeRect, x, y, w, h);
	},

	/*
	 * path API
	 */

	beginPath: function() {
		this._queue.push(properties.beginPath);
	},

	closePath: function() {
		this._queue.push(properties.closePath);
	},

	moveTo: function(x, y) {
		this._queue.push(properties.moveTo, x, y);
	},

	lineTo: function(x, y) {
		this._queue.push(properties.lineTo, x, y);
	},

	quadraticCurveTo: function(cpx, cpy, x, y) {
		this._queue.push(properties.quadraticCurveTo, cpx, cpy, x, y);
	},

	bezierCurveTo: function(cp1x, cp1y, cp2x, cp2y, x, y) {
		this._queue.push(properties.bezierCurveTo, cp1x, cp1y, cp2x, cp2y, x, y);
	},

	arcTo: function(x1, y1, x2, y2, radius) {
		this._queue.push(properties.arcTo, x1, y1, x2, y2, radius);
	},

	rect: function(x, y, w, h) {
		this._queue.push(properties.rect, x, y, w, h);
	},

	arc: function(x, y, radius, startAngle, endAngle, anticlockwise) {
		anticlockwise = anticlockwise ? 1 : 0;
		this._queue.push(properties.arc, x, y, radius, startAngle, endAngle, anticlockwise);
	},

	fill: function() {
		this._setCompositing();
		this._setShadows();
		this._setFillStyle();
		this._queue.push(properties.fill);
	},

	stroke: function() {
		this._setCompositing();
		this._setShadows();
		this._setStrokeStyle();
		this._setLineStyles();
		this._queue.push(properties.stroke);
	},

	clip: function() {
		this._queue.push(properties.clip);
	},

	isPointInPath: function(x, y) {
		// TODO: Implement
	},

	/*
	 * text
	 */

	_setFontStyles: function() {
		var queue = this._queue;
		if (this._font != this.font) {
			this._font = this.font;
			
			try {
			  this._swf.style.font = this.font;
			} catch (e) {}
			var style = this._swf.currentStyle;
			
			// @fixme: The font size is not always in "px"
			var font = [style.fontStyle, style.fontWeight, style.fontSize, style.fontFamily].join(" ");
			queue.push(properties.font, font);
		}
		if (this._textAlign != this.textAlign) {
			this._textAlign = this.textAlign;
			queue.push(properties.textAlign, this.textAlign);
		}
		if (this._textBaseline != this.textBaseline) {
			this._textBaseline = this.textBaseline;
			queue.push(properties.textBaseline, this.textBaseline);
		}
	},

	// void fillText(in DOMString text, in float x, in float y, [Optional] in float maxWidth);
	fillText: function(text, x, y, maxWidth) {
		this._setCompositing();
		this._setFillStyle();
		this._setShadows();
		this._setFontStyles();
		this._queue.push(properties.fillText, text, x, y, maxWidth);
	},

	// void strokeText(in DOMString text, in float x, in float y, [Optional] in float maxWidth);
	strokeText: function(text, x, y, maxWidth) {
		this._setCompositing();
		this._setStrokeStyle();
		this._setShadows();
		this._setFontStyles();
		this._queue.push(properties.strokeText, text, x, y, maxWidth);
	},

	// TextMetrics measureText(in DOMString text);
	measureText: function(text) {
		// TODO: Implement
	},

	/*
	 * drawing images
	 */

	drawImage: function() {
		var a = arguments, argc = a.length;

		// The first argument is HTMLImageElement, HTMLCanvasElement or
		// HTMLVideoElement. For now, only HTMLImageElement is supported.
		if (a[0].tagName.toUpperCase() !== "IMG") return;

		this._setCompositing();
		this._setShadows();

		if (argc === 3) {
			this._queue.push(properties.drawImage, argc, a[0].src, a[1], a[2]);
		} else if (argc === 5) {
			this._queue.push(properties.drawImage, argc, a[0].src, a[1], a[2], a[3], a[4]);
		} else if (argc === 9) {
			this._queue.push(properties.drawImage, argc, a[0].src, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]);
		} else {
			return;
		}

		if (isReady[this._canvasId]) {
			this._postCommands();
			++lock[this._canvasId];
		}
	},

	/*
	 * pixel manipulation
	 */

	// ImageData createImageData(in float sw, in float sh);
	// ImageData createImageData(in ImageData imagedata);
	createImageData: function() {
		// TODO: Implement
	},

	// ImageData getImageData(in float sx, in float sy, in float sw, in float sh);
	getImageData: function(sx, sy, sw, sh) {
		// TODO: Implement
	},

	// void putImageData(in ImageData imagedata, in float dx, in float dy, [Optional] in float dirtyX, in float dirtyY, in float dirtyWidth, in float dirtyHeight);
	putImageData: function(imagedata, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight) {
		// TODO: Implement
	},

	/*
	 * private methods
	 */

	_initialize: function() {
		// compositing
		this.globalAlpha = this._globalAlpha = 1.0;
		this.globalCompositeOperation = this._globalCompositeOperation = "source-over";

		// colors and styles
		this.strokeStyle = this._strokeStyle = "#000000";
		this.fillStyle   = this._fillStyle   = "#000000";

		// line caps/joins
		this.lineWidth  = this._lineWidth  = 1.0;
		this.lineCap    = this._lineCap    = "butt";
		this.lineJoin   = this._lineJoin   = "miter";
		this.miterLimit = this._miterLimit = 10.0;

		// shadows
		this.shadowOffsetX = this._shadowOffsetX = 0;
		this.shadowOffsetY = this._shadowOffsetY = 0;
		this.shadowBlur    = this._shadowBlur    = 0;
		this.shadowColor   = this._shadowColor   = "rgba(0,0,0,0)";

		// text
		this.font         = this._font         = "10px sans-serif";
		this.textAlign    = this._textAlign    = "start";
		this.textBaseline = this._textBaseline = "alphabetic";

		// command queue
		this._queue = [];

		// stack of drawing states
		this._stateStack = [];
	},

	_flush: function() {
		var queue = this._queue;
		this._queue = [];
		return queue;
	},

	_postCommands: function() {
		// post commands
		var commands = this._flush();
		if (commands.length > 0) {
			return eval(this._swf.CallFunction(
				'<invoke name="postCommands" returntype="javascript"><arguments><string>'
				+ commands.join("&#0;") + "</string></arguments></invoke>"
			));
		}
	},

	_resize: function(width, height) {
		// resize frame
		this._swf.resize(width, height);

		// clear back to the initial state
		this._initialize();
	}
};

/*
 * CanvasGradient stub
 */

var CanvasGradient = function(ctx) {
	this._ctx = ctx;
	this.id   = getStyleId(ctx);
};

CanvasGradient.prototype = {
	addColorStop: function(offset, color) {
		this._ctx._queue.push(properties.addColorStop, this.id, offset, color);
	}
};

/*
 * CanvasPattern stub
 */

var CanvasPattern = function(ctx) {
	this.id = getStyleId(ctx);
};

/*
 * Event handlers
 */

function onReadyStateChange() {
	if (document.readyState === "complete") {
		document.detachEvent("onreadystatechange", onReadyStateChange);

		var elements = document.getElementsByTagName("canvas");
		for (var i = 0, len = elements.length; i < len; ++i) {
			var canvas = elements[i];
			if (!canvas.getContext) {
				FlashCanvas.initElement(canvas);
			}
		}
	}
}

function onPropertyChange(event) {
	var prop = event.propertyName;
	if (prop === "width" || prop === "height") {
		var canvas = event.srcElement, ctx = canvas.getContext("2d");
		var value = parseInt(canvas[prop]);
		if (isNaN(value) || value < 0) {
			value = (prop === "width") ? 300 : 150;
		}
		canvas.style[prop] = value + "px";
		ctx._resize(canvas.clientWidth, canvas.clientHeight);
	}
}

function onFocus(event) {
	// forward the event to the parent
	var swf = event.srcElement, canvas = swf.parentNode;
	swf.blur();
	canvas.focus();
}

function onBeforeUnload() {
	window.detachEvent("onbeforeunload", onBeforeUnload);

	var elements = document.getElementsByTagName("canvas");
	for (var i = 0, len = elements.length; i < len; ++i) {
		var canvas = elements[i], swf = canvas.firstChild, prop;

		// clean up the references of swf.postCommands and swf.resize
		for (prop in swf) {
			if (typeof swf[prop] === "function") {
				swf[prop] = null;
			}
		}

		// clean up the references of canvas.getContext and canvas.toDataURL
		for (prop in canvas) {
			if (typeof canvas[prop] === "function") {
				canvas[prop] = null;
			}
		}

		// remove event listeners
		canvas.detachEvent("onpropertychange", onPropertyChange);
		swf.detachEvent("onfocus", onFocus);
	}

	// delete exported symbols
	window["CanvasRenderingContext2D"] = null;
	window["CanvasGradient"]           = null;
	window["CanvasPattern"]            = null;
	window["FlashCanvas"]              = null;
}

/*
 * FlashCanvas API
 */

var FlashCanvas = {
	initElement: function(canvas) {
		// get element explicit size
		var width = 300, height = 150;
		if (canvas.attributes["width"] != undefined)
			width = Math.max(Number(canvas.getAttribute("width")) || 0, 0);
		if (canvas.attributes["height"] != undefined)
			height = Math.max(Number(canvas.getAttribute("height")) || 0, 0);
		canvas.style.width  = width  + "px";
		canvas.style.height = height + "px";

		// initialize lock
		var canvasId      = canvas.uniqueID;
		isReady[canvasId] = false;
		lock[canvasId]    = 1;

		// embed swf
		canvas.innerHTML =
			'<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"' +
			' codebase="http://fpdownload.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=9,0,0,0"' +
			' width="100%" height="100%" id="external' + canvasId + '">' +
			'<param name="allowScriptAccess" value="always">' +
			'<param name="movie" value="' + SWF_URL + '">' +
			'<param name="quality" value="high">' +
			'<param name="wmode" value="transparent">' +
			'</object>';
		var swf = canvas.firstChild;

		// initialize context
		var ctx = new CanvasRenderingContext2D(canvas, swf);

		// canvas API
		canvas.getContext = function(contextId) {
			return contextId === "2d" ? ctx : null;
		};

		canvas.toDataURL = function() {
			var a = arguments, type = a[0] ? a[0].toLowerCase() : "image/png";

			if (type === "image/jpeg") {
				ctx._queue.push(properties.toDataURL, type, a[1] || 0.5);
			} else {
				ctx._queue.push(properties.toDataURL, type);
			}
			return ctx._postCommands();
		};

		// add event listeners
		canvas.attachEvent("onpropertychange", onPropertyChange);
		swf.attachEvent("onfocus", onFocus);
	},

	unlock: function(canvasId, ready) {
		if (lock[canvasId]) {
			--lock[canvasId];
		}
		if (ready) {
			var swf = document.getElementById("external" + canvasId);
			swf.resize(swf.clientWidth, swf.clientHeight);
			isReady[canvasId] = true;
		}
	}
};

/*
 * Utility methods
 */

function getScriptUrl() {
	var scripts = document.getElementsByTagName("script");
	var script  = scripts[scripts.length - 1];
	return script.getAttribute("src", 2);
}

/*
 * initialization
 */

// IE HTML5 shiv
document.createElement("canvas");

// setup default CSS
document.createStyleSheet().cssText =
	"canvas{display:inline-block;overflow:hidden;width:300px;height:150px}";

// initialize canvas elements
document.attachEvent("onreadystatechange", onReadyStateChange);

// prevent IE6 memory leaks
window.attachEvent("onbeforeunload", onBeforeUnload);

// determine SWF url
var path    = getScriptUrl().replace(/[^\/]+$/, "");
var SWF_URL = path + "flashcanvas.swf";  // + "?r=" + Math.random();

// cache SWF data so that object is interactive upon writing
var req = new ActiveXObject("Microsoft.XMLHTTP");
req.open("GET", SWF_URL, false);
req.send(null);

/*
 * public API
 */

window["CanvasRenderingContext2D"] = CanvasRenderingContext2D;
window["CanvasGradient"]   = CanvasGradient;
window["CanvasPattern"]    = CanvasPattern;
window["FlashCanvas"]      = FlashCanvas;
FlashCanvas["initElement"] = FlashCanvas.initElement;
FlashCanvas["unlock"]      = FlashCanvas.unlock;

})();

}
