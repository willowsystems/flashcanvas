/*
 * FlashCanvas
 *
 * Copyright (c) 2009      Tim Cameron Ryan
 * Copyright (c) 2009-2010 FlashCanvas Project
 * Licensed under the MIT License.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * @author Colin Leung (developed ASCanvas)
 * @author Tim Cameron Ryan
 * @author Shinya Muramatsu
 * @see    http://code.google.com/p/ascanvas/
 */

package com.googlecode.flashcanvas
{
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.BlendMode;
    import flash.display.CapsStyle;
    import flash.display.Graphics;
    import flash.display.InterpolationMethod;
    import flash.display.JointStyle;
    import flash.display.LineScaleMode;
    import flash.display.Loader;
    import flash.display.LoaderInfo;
    import flash.display.Shape;
    import flash.display.SpreadMethod;
    import flash.events.Event;
    import flash.external.ExternalInterface;
    import flash.geom.ColorTransform;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;
    import flash.net.URLRequest;
    import flash.utils.ByteArray;

    public class CanvasRenderingContext2D
    {
        // back-reference to the canvas
        private var _canvas:Canvas;

        // vector shape
        private var shape:Shape;

        // clipping region
        private var clippingMask:Shape;

        // current path
        private var path:Array = [];

        // first point of the current subpath
        private var startingPoint:Point;

        // last point of the current subpath
        private var currentPoint:Point;

        // stack of drawing states
        private var stateStack:Array = [];

        // drawing state
        private var state:State;

        // cache for BitmapData
        private var imageCache:Object = {};

        // queue used in drawImage()
        private var taskQueue:Array = [];

        public function CanvasRenderingContext2D(canvas:Canvas)
        {
            _canvas = canvas;

            shape        = new Shape();
            clippingMask = new Shape();
            shape.mask   = clippingMask;

            startingPoint = new Point();
            currentPoint  = new Point();

            state = new State();
        }

        public function resize(width:int, height:int):void
        {
            // initialize bitmapdata
            _canvas.resize(width, height);

            // initialize drawing states
            stateStack = [];
            state = new State();

            // draw initial clipping region
            beginPath();
            rect(0, 0, width, height);
            clip();

            // clear the current path
            beginPath();
        }

        /*
         * back-reference to the canvas
         */

        public function get canvas():Canvas
        {
            return _canvas;
        }

        /*
         * state
         */

        public function save():void
        {
            stateStack.push(state.clone());
        }

        public function restore():void
        {
            if (stateStack.length == 0)
                return;

            state = stateStack.pop();

            // redraw clipping image
            var graphics:Graphics = clippingMask.graphics;
            graphics.clear();
            graphics.beginFill(0x000000);
            _drawPath(graphics, state.clipPath);
            graphics.endFill();
        }

        /*
         * transformations
         */

        public function scale(sx:Number, sy:Number):void
        {
            var matrix:Matrix = state.transformMatrix.clone();
            state.transformMatrix.identity();
            state.transformMatrix.scale(sx, sy);
            state.transformMatrix.concat(matrix);

            state.lineScale *= Math.sqrt(Math.abs(sx * sy));
        }

        public function rotate(angle:Number):void
        {
            var matrix:Matrix = state.transformMatrix.clone();
            state.transformMatrix.identity();
            state.transformMatrix.rotate(angle);
            state.transformMatrix.concat(matrix);
        }

        public function translate(tx:Number, ty:Number):void
        {
            var matrix:Matrix = state.transformMatrix.clone();
            state.transformMatrix.identity();
            state.transformMatrix.translate(tx, ty);
            state.transformMatrix.concat(matrix);
        }

        public function transform(m11:Number, m12:Number, m21:Number, m22:Number, dx:Number, dy:Number):void
        {
            var matrix:Matrix = state.transformMatrix.clone();
            state.transformMatrix = new Matrix(m11, m12, m21, m22, dx, dy);
            state.transformMatrix.concat(matrix);

            state.lineScale *= Math.sqrt(Math.abs(m11 * m22 - m12 * m21));
        }

        public function setTransform(m11:Number, m12:Number, m21:Number, m22:Number, dx:Number, dy:Number):void
        {
            state.transformMatrix = new Matrix(m11, m12, m21, m22, dx, dy);

            state.lineScale = Math.sqrt(Math.abs(m11 * m22 - m12 * m21));
        }

        /*
         * compositing
         */

        public function get globalAlpha():Number
        {
            return state.globalAlpha;
        }

        public function set globalAlpha(value:Number):void
        {
            if (isFinite(value) && 0.0 <= value && value <= 1.0)
                state.globalAlpha = value;
        }

        public function get globalCompositeOperation():String
        {
            return state.globalCompositeOperation;
        }

        public function set globalCompositeOperation(value:String):void
        {
            state.globalCompositeOperation = value;
        }

        /*
         * colors and styles
         */

        public function get strokeStyle():*
        {
            if (state.strokeStyle is CSSColor)
                return state.strokeStyle.toString();
            else
                return state.strokeStyle;
        }

        public function set strokeStyle(value:*):void
        {
            if (value is String)
            {
                try
                {
                    state.strokeStyle = new CSSColor(value);
                }
                catch (e:ArgumentError)
                {
                    // Ignore the value
                }
            }
            else if (value is CanvasGradient || value is CanvasPattern)
            {
                state.strokeStyle = value;
            }
        }

        public function get fillStyle():*
        {
            if (state.fillStyle is CSSColor)
                return state.fillStyle.toString();
            else
                return state.fillStyle;
        }

        public function set fillStyle(value:*):void
        {
            if (value is String)
            {
                try
                {
                    state.fillStyle = new CSSColor(value);
                }
                catch (e:ArgumentError)
                {
                    // Ignore the value
                }
            }
            else if (value is CanvasGradient || value is CanvasPattern)
            {
                state.fillStyle = value;
            }
        }

        public function createLinearGradient(x0:Number, y0:Number, x1:Number, y1:Number):LinearGradient
        {
            return new LinearGradient(x0, y0, x1, y1);
        }

        public function createRadialGradient(x0:Number, y0:Number, r0:Number, x1:Number, y1:Number, r1:Number):RadialGradient
        {
            return new RadialGradient(x0, y0, r0, x1, y1, r1);
        }

        public function createPattern(image:*, repetition:String):CanvasPattern
        {
            return new CanvasPattern(image, repetition);
        }

        /*
         * line caps/joins
         */

        public function get lineWidth():Number
        {
            return state.lineWidth;
        }

        public function set lineWidth(value:Number):void
        {
            if (isFinite(value) && value > 0)
                state.lineWidth = value;
        }

        public function get lineCap():String
        {
            if (state.lineCap == CapsStyle.NONE)
                return "butt";
            else if (state.lineCap == CapsStyle.ROUND)
                return "round";
            else
                return "square";
        }

        public function set lineCap(value:String):void
        {
            if (value == "butt")
                state.lineCap = CapsStyle.NONE;
            else if (value == "round")
                state.lineCap = CapsStyle.ROUND;
            else if (value == "square")
                state.lineCap = CapsStyle.SQUARE;
        }

        public function get lineJoin():String
        {
            if (state.lineJoin == JointStyle.BEVEL)
                return "bevel";
            else if (state.lineJoin == JointStyle.ROUND)
                return "round";
            else
                return "miter";
        }

        public function set lineJoin(value:String):void
        {
            if (value == "bevel")
                state.lineJoin = JointStyle.BEVEL;
            else if (value == "round")
                state.lineJoin = JointStyle.ROUND;
            else if (value == "miter")
                state.lineJoin = JointStyle.MITER;
        }

        public function get miterLimit():Number
        {
            return state.miterLimit;
        }

        public function set miterLimit(value:Number):void
        {
            if (isFinite(value) && value > 0)
                state.miterLimit = value;
        }

        /*
         * shadows
         */

        public function get shadowOffsetX():Number
        {
            return state.shadowOffsetX;
        }

        public function set shadowOffsetX(value:Number):void
        {
            state.shadowOffsetX = value;
        }

        public function get shadowOffsetY():Number
        {
            return state.shadowOffsetY;
        }

        public function set shadowOffsetY(value:Number):void
        {
            state.shadowOffsetY = value;
        }

        public function get shadowBlur():Number
        {
            return state.shadowBlur;
        }

        public function set shadowBlur(value:Number):void
        {
            state.shadowBlur = value;
        }

        public function get shadowColor():String
        {
            return state.shadowColor.toString();
        }

        public function set shadowColor(value:String):void
        {
            try
            {
                state.shadowColor = new CSSColor(value);
            }
            catch (e:ArgumentError)
            {
                // Ignore the value
            }
        }

        /*
         * rects
         */

        public function clearRect(x:Number, y:Number, w:Number, h:Number):void
        {
            if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h))
                return;

            var shape:Shape       = new Shape();
            var graphics:Graphics = shape.graphics;

            graphics.beginFill(0x000000);
            graphics.drawRect(x, y, w, h);
            graphics.endFill();

            _canvas.bitmapData.draw(shape, state.transformMatrix, null, BlendMode.ERASE);
        }

        public function fillRect(x:Number, y:Number, w:Number, h:Number):void
        {
            if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h))
                return;

            var p1:Point = _getTransformedPoint(x, y);
            var p2:Point = _getTransformedPoint(x + w, y);
            var p3:Point = _getTransformedPoint(x + w, y + h);
            var p4:Point = _getTransformedPoint(x, y + h);

            var graphics:Graphics = shape.graphics;

            _setFillStyle(graphics);
            graphics.moveTo(p1.x, p1.y);
            graphics.lineTo(p2.x, p2.y);
            graphics.lineTo(p3.x, p3.y);
            graphics.lineTo(p4.x, p4.y);
            graphics.lineTo(p1.x, p1.y);
            graphics.endFill();

            _renderShape();
        }

        public function strokeRect(x:Number, y:Number, w:Number, h:Number):void
        {
            if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h))
                return;

            var p1:Point = _getTransformedPoint(x, y);
            var p2:Point = _getTransformedPoint(x + w, y);
            var p3:Point = _getTransformedPoint(x + w, y + h);
            var p4:Point = _getTransformedPoint(x, y + h);

            var graphics:Graphics = shape.graphics;

            _setStrokeStyle(graphics);
            graphics.moveTo(p1.x, p1.y);
            graphics.lineTo(p2.x, p2.y);
            graphics.lineTo(p3.x, p3.y);
            graphics.lineTo(p4.x, p4.y);
            graphics.lineTo(p1.x, p1.y);

            _renderShape();
        }

        /*
         * path API
         */

        public function beginPath():void
        {
            path = [];
        }

        public function closePath():void
        {
            if (path.length == 0)
                return;

            path.push({
                command: "lineTo",
                data: [ startingPoint.x, startingPoint.y ]
            });

            currentPoint.x = startingPoint.x;
            currentPoint.y = startingPoint.y;
        }

        public function moveTo(x:Number, y:Number):void
        {
            if (!isFinite(x) || !isFinite(y))
                return;

            var p:Point = _getTransformedPoint(x, y);

            path.push({
                command: "moveTo",
                data: [ p.x, p.y ]
            });

            startingPoint.x = currentPoint.x = p.x;
            startingPoint.y = currentPoint.y = p.y;
        }

        public function lineTo(x:Number, y:Number):void
        {
            if (!isFinite(x) || !isFinite(y))
                return;

            // check that path contains subpaths
            if (path.length == 0)
                moveTo(x, y);

            var p:Point = _getTransformedPoint(x, y);

            path.push({
                command: "lineTo",
                data: [ p.x, p.y ]
            });

            currentPoint.x = p.x;
            currentPoint.y = p.y;
        }

        public function quadraticCurveTo(cpx:Number, cpy:Number, x:Number, y:Number):void
        {
            if (!isFinite(cpx) || !isFinite(cpy) || !isFinite(x) || !isFinite(y))
                return;

            // check that path contains subpaths
            if (path.length == 0)
                moveTo(cpx, cpy);

            var cp:Point = _getTransformedPoint(cpx, cpy);
            var  p:Point = _getTransformedPoint(x, y);

            path.push({
                command: "quadraticCurveTo",
                data: [ cp.x, cp.y, p.x, p.y ]
            });

            currentPoint.x = p.x;
            currentPoint.y = p.y;
        }

        public function bezierCurveTo(cp1x:Number, cp1y:Number, cp2x:Number, cp2y:Number, x:Number, y:Number):void
        {
            if (!isFinite(cp1x) || !isFinite(cp1y) || !isFinite(cp2x) || !isFinite(cp2y) || !isFinite(x) || !isFinite(y))
                return;

            // check that path contains subpaths
            if (path.length == 0)
                moveTo(cp1x, cp1y);

            var cp1:Point = _getTransformedPoint(cp1x, cp1y);
            var cp2:Point = _getTransformedPoint(cp2x, cp2y);
            var   p:Point = _getTransformedPoint(x, y);

            path.push({
                command: "bezierCurveTo",
                data: [ cp1.x, cp1.y, cp2.x, cp2.y, p.x, p.y, currentPoint.x, currentPoint.y ]
            });

            currentPoint.x = p.x;
            currentPoint.y = p.y;
        }

        public function arcTo(x1:Number, y1:Number, x2:Number, y2:Number, radius:Number):void
        {
            if (!isFinite(x1) || !isFinite(y1) || !isFinite(x2) || !isFinite(y2) || !isFinite(radius))
                return;

            // check that path contains subpaths
            if (path.length == 0)
                moveTo(x1, y1);

            var p1:Point = _getTransformedPoint(x1, y1);
            var p2:Point = _getTransformedPoint(x2, y2);

            // check that coordinates aren't equal
            if (currentPoint.equals(p1))
            {
                path.push({
                    command: "lineTo",
                    data: [ p1.x, p1.y ]
                });
            }

            path.push({
                command: "arcTo",
                data: [ p1.x, p1.y, p2.x, p2.y, radius, currentPoint.x, currentPoint.y ]
            });

            currentPoint.x = p2.x;
            currentPoint.y = p2.y;
        }

        public function rect(x:Number, y:Number, w:Number, h:Number):void
        {
            if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h))
                return;

            var p1:Point = _getTransformedPoint(x, y);
            var p2:Point = _getTransformedPoint(x + w, y);
            var p3:Point = _getTransformedPoint(x + w, y + h);
            var p4:Point = _getTransformedPoint(x, y + h);

            path.push({
                command: "rect",
                data: [ p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y ]
            });

            startingPoint.x = currentPoint.x = p1.x;
            startingPoint.y = currentPoint.y = p1.y;
        }

        public function arc(x:Number, y:Number, radius:Number, startAngle:Number, endAngle:Number, anticlockwise:Boolean):void
        {
            var startX:Number = x + radius * Math.cos(startAngle);
            var startY:Number = y + radius * Math.sin(startAngle);
            var endX:Number   = x + radius * Math.cos(endAngle);
            var endY:Number   = y + radius * Math.sin(endAngle);

            var p:Point  = _getTransformedPoint(x, y);
            var p1:Point = _getTransformedPoint(startX, startY);
            var p2:Point = _getTransformedPoint(endX, endY);

            // check that path contains subpaths
            if (path.length == 0)
            {
                path.push({
                    command: "moveTo",
                    data: [ p1.x, p1.y ]
                });

                startingPoint.x = p1.x;
                startingPoint.y = p1.y;
            }
            else
            {
                path.push({
                    command: "lineTo",
                    data: [ p1.x, p1.y ]
                });
            }

            path.push({
                command: "arc",
                data: [ p.x, p.y, radius, startAngle, endAngle, anticlockwise ]
            });

            currentPoint.x = p2.x;
            currentPoint.y = p2.y;
        }

        public function fill():void
        {
            var graphics:Graphics = shape.graphics;
            _setFillStyle(graphics);
            _drawPath(graphics, path);
            graphics.endFill();
            _renderShape();
        }

        public function stroke():void
        {
            var graphics:Graphics = shape.graphics;
            _setStrokeStyle(graphics);
            _drawPath(graphics, path);
            _renderShape();
        }

        public function clip():void
        {
            // extract path
            state.clipPath = path;

            // draw paths
            var graphics:Graphics = clippingMask.graphics;
            graphics.clear();
            graphics.beginFill(0x000000);
            _drawPath(graphics, state.clipPath);
            graphics.endFill();
        }

        public function isPointInPath(x:Number, y:Number):*
        {
            // TODO: Implement
        }

        /*
         * text
         */

        public function get font():*
        {
            return state.font;
        }

        public function set font(value:String):void
        {
            state.font = value;
        }

        private function _parseFont():TextFormat
        {
            var format:TextFormat = new TextFormat;
            var fontData:Array = state.font.split(" ");

            format.italic = fontData[0] == "italic";
            format.size = parseFloat(fontData[2]);
            format.font = fontData.slice(3).join(" ").replace(/["']/g, "");

            var weight:Number = parseInt(fontData[1]);
            format.bold = (!isNaN(weight) && weight > 400 || fontData[1] == "bold");

            return format;
        }

        public function get textAlign():*
        {
            return state.textAlign;
        }

        public function set textAlign(value:String):void
        {
            switch (value)
            {
                case "start":
                case "end":
                case "left":
                case "right":
                case "center":
                    state.textAlign = value;
            }
        }

        public function get textBaseline():*
        {
            return state.textBaseline;
        }

        public function set textBaseline(value:String):void
        {
            switch (value)
            {
                case "top":
                case "hanging":
                case "middle":
                case "alphabetic":
                case "ideographic":
                case "bottom":
                    state.textBaseline = value;
            }
        }

        public function fillText(text:String, x:Number, y:Number, maxWidth:Number = Infinity):void
        {
            _renderText(text, x, y, maxWidth);
        }

        public function strokeText(text:String, x:Number, y:Number, maxWidth:Number = Infinity):void
        {
            _renderText(text, x, y, maxWidth, true);
        }

        public function measureText():*
        {
            // TODO: Implement
        }

        /*
         * drawing images
         */

        public function drawImage(image:*, ...args:Array):void
        {
            var url:String = image.src;

            // If the image is already in the cache
            if (imageCache[url])
            {
                // Render the image immediately
                _renderImage(imageCache[url], args);
            }

            // If the image is not in the cache
            else
            {
                // Enqueue the task
                taskQueue.push({
                    url:   url,
                    args:  args,
                    state: state.clone()
                });

                // If the image is being loaded
                if (url in imageCache)
                {
                    // Do nothing
                }

                // If this is the first time to access the URL
                else
                {
                    // Use the URL as a hash key
                    imageCache[url] = null;

                    var loader:Loader = new Loader();

                    // Register a listener for a complete event
                    loader.contentLoaderInfo.addEventListener(Event.COMPLETE, _completeHandler(url));

                    if (url.slice(0, 11) == "data:image/")
                    {
                        // Decode data URI
                        var data:String         = url.slice(url.indexOf(",") + 1);
                        var byteArray:ByteArray = Base64.decode(data);
                        loader.loadBytes(byteArray);
                    }
                    else
                    {
                        // If the file is in other domain
                        if (/^https?:\/\//.test(url))
                        {
                            // Rewrite the URL to load the file via a proxy script
                            url = Config.proxy + '?url=' + url;
                        }

                        // Load the image
                        var request:URLRequest = new URLRequest(url);
                        loader.load(request);
                    }
                }
            }
        }

        private function _completeHandler(url:String):Function
        {
            return function(event:Event):void
            {
                // Remove the event listener
                var loaderInfo:LoaderInfo = event.target as LoaderInfo;
                loaderInfo.removeEventListener(Event.COMPLETE, _completeHandler);

                // Cache BitmapData of the image
                imageCache[url] = Bitmap(loaderInfo.content).bitmapData;

                // Process the tasks in order
                while (taskQueue.length > 0)
                {
                    // Get the URL property
                    url = taskQueue[0].url;

                    // If the BitmapData is not ready, we defer the execution
                    // of the remaining tasks.
                    if (!imageCache[url])
                        break;

                    // Dequeue the object
                    var task:Object = taskQueue.shift();

                    // Render the image
                    var args:Array  = task.args;
                    var state:State = task.state;
                    _renderImage(imageCache[url], args, state);
                }

                // Remove the prefix "external" from objectID
                var canvasId:String = ExternalInterface.objectID.slice(8);

                // Send JavaScript a message that the image has been drawn
                ExternalInterface.call("FlashCanvas.unlock", canvasId);

                // Release the memory
                loaderInfo.loader.unload();
            }
        }

        /*
         * pixel manipulation
         */

        public function createImageData():ImageData
        {
            // TODO: Implement
            return new ImageData;
        }

        public function getImageData(sx:Number, sy:Number, sw:Number, sh:Number):ImageData
        {
            // TODO: Implement
            return new ImageData;
        }

        public function putImageData(data:ImageData, dx:Number, dy:Number, dirtyX:Number, dirtyY:Number, dirtyWidth:Number, dirtyHeight:Number):void
        {
            // TODO: Implement
        }

        /*
         * private methods
         */

        private function _getTransformedPoint(x:Number, y:Number):Point
        {
            return state.transformMatrix.transformPoint(new Point(x, y));
        }

        private function _setStrokeStyle(graphics:Graphics):void
        {
            var style:Object         = state.strokeStyle;
            var thickness:Number     = state.lineWidth * state.lineScale;
            var color:uint           = 0;
            var alpha:Number         = 1.0;
            var pixelHinting:Boolean = true;

            if (style is CSSColor)
            {
                color = style.color;
                alpha = style.alpha * state.globalAlpha;

                if (thickness < 1)
                    alpha *= thickness;
            }

            graphics.lineStyle(thickness, color, alpha, pixelHinting, LineScaleMode.NORMAL, state.lineCap, state.lineJoin, state.miterLimit);

            if (style is CanvasGradient)
            {
                var alphas:Array = style.alphas;
                if (state.globalAlpha < 1)
                {
                    for (var i:int = 0, n:int = alphas.length; i < n; i++)
                    {
                        alphas[i] *= state.globalAlpha;
                    }
                }

                var matrix:Matrix = style.matrix.clone();
                matrix.concat(state.transformMatrix);

                graphics.lineGradientStyle(style.type, style.colors, alphas, style.ratios, matrix, SpreadMethod.PAD, InterpolationMethod.RGB, style.focalPointRatio);
            }
            else if (style is CanvasPattern)
            {
                // Flash 9 does not support this API.
            }
        }

        private function _setFillStyle(graphics:Graphics):void
        {
            // disable stroke
            graphics.lineStyle();

            var style:Object = state.fillStyle;

            if (style is CSSColor)
            {
                var color:uint   = style.color;
                var alpha:Number = style.alpha * state.globalAlpha;
                graphics.beginFill(color, alpha);
            }
            else if (style is CanvasGradient)
            {
                var alphas:Array = style.alphas;
                if (state.globalAlpha < 1)
                {
                    for (var i:int = 0, n:int = alphas.length; i < n; i++)
                    {
                        alphas[i] *= state.globalAlpha;
                    }
                }

                var matrix:Matrix = style.matrix.clone();
                matrix.concat(state.transformMatrix);

                graphics.beginGradientFill(style.type, style.colors, alphas, style.ratios, matrix, SpreadMethod.PAD, InterpolationMethod.RGB, style.focalPointRatio);
            }
            else if (style is CanvasPattern)
            {
                var bitmap:BitmapData = style.bitmapData;

                if (state.globalAlpha < 1)
                {
                    var colorTransform:ColorTransform =
                        new ColorTransform(1, 1, 1, state.globalAlpha);

                    // Make a translucent BitmapData
                    bitmap = style.bitmapData.clone();
                    bitmap.colorTransform(bitmap.rect, colorTransform);
                }

                // TODO: support repetition other than 'repeat'.
                graphics.beginBitmapFill(bitmap, state.transformMatrix);
            }
        }

        private function _drawPath(graphics:Graphics, path:Array):void
        {
            for (var i:int = 0, n:int = path.length; i < n; i++)
            {
                var command:String = path[i].command;
                var data:Array     = path[i].data;

                switch (command) {
                    case "moveTo":
                        _moveTo(graphics, data);
                        break;

                    case "lineTo":
                        _lineTo(graphics, data);
                        break;

                    case "quadraticCurveTo":
                        _quadraticCurveTo(graphics, data);
                        break;

                    case "bezierCurveTo":
                        _bezierCurveTo(graphics, data);
                        break;

                    case "arcTo":
                        _arcTo(graphics, data);
                        break;

                    case "rect":
                        _rect(graphics, data);
                        break;

                    case "arc":
                        _arc(graphics, data);
                        break;
                }
            }
        }

        private function _moveTo(graphics:Graphics, arg:Array):void
        {
            var x:Number = arg[0];
            var y:Number = arg[1];
            graphics.moveTo(x, y);
        }

        private function _lineTo(graphics:Graphics, arg:Array):void
        {
            var x:Number = arg[0];
            var y:Number = arg[1];
            graphics.lineTo(x, y);
        }

        private function _quadraticCurveTo(graphics:Graphics, arg:Array):void
        {
            var cpx:Number = arg[0];
            var cpy:Number = arg[1];
            var   x:Number = arg[2];
            var   y:Number = arg[3];
            graphics.curveTo(cpx, cpy, x, y);
        }

        private function _bezierCurveTo(graphics:Graphics, arg:Array):void
        {
            var p0:Point = new Point(arg[6], arg[7]);
            var p1:Point = new Point(arg[0], arg[1]);
            var p2:Point = new Point(arg[2], arg[3]);
            var p3:Point = new Point(arg[4], arg[5]);

            var bezier:Bezier = new Bezier(graphics);
            bezier.drawCubicBezier(p0, p1, p2, p3, 4);
        }

        private function _arcTo(graphics:Graphics, arg:Array):void
        {
            var x0:Number = arg[5];
            var y0:Number = arg[6];
            var x1:Number = arg[0];
            var y1:Number = arg[1];
            var x2:Number = arg[2];
            var y2:Number = arg[3];
            var radius:Number = arg[4];

            var theta:Number = Math.atan2(y0 - y1, x0 - x1) - Math.atan2(y2 - y1, x2 - x1);
            var lengthFromP1ToT1:Number = Math.abs(radius / Math.tan(theta / 2));
            var lengthFromP1ToC1:Number = Math.abs(radius / Math.sin(theta / 2));

            var xt0:Number = (x0 - x1);
            var yt0:Number = (y0 - y1);
            var l:Number = Math.sqrt((xt0 * xt0) + (yt0 * yt0));
            xt0 = xt0 * lengthFromP1ToT1 / l + x1;
            yt0 = yt0 * lengthFromP1ToT1 / l + y1;

            var xt2:Number = (x2 - x1);
            var yt2:Number = (y2 - y1);
            l = Math.sqrt((xt2 * xt2) + (yt2 * yt2));
            xt2 = xt2 * lengthFromP1ToT1 / l + x1;
            yt2 = yt2 * lengthFromP1ToT1 / l + y1;

            var cx:Number = (xt0 + xt2) * 0.5 - x1;
            var cy:Number = (yt0 + yt2) * 0.5 - y1;
            l = Math.sqrt((cx * cx) + (cy * cy));
            cx = cx * lengthFromP1ToC1 / l + x1;
            cy = cy * lengthFromP1ToC1 / l + y1;

            var d:Draw = new Draw(graphics, state.transformMatrix);
            var startAngle:Number = Math.atan2(yt0 - cy, xt0 - cx);
            var endAngle:Number = Math.atan2(yt2 - cy, xt2 - cx);
            var anticlockwise:Boolean = (x0 - x1) * (y2 - y1) > (x2 - x1) * (y0 - y1);

            graphics.moveTo(x0, y0);
            graphics.lineTo(xt0, yt0);
            d.arc(cx, cy, radius, startAngle, endAngle, anticlockwise);
        }

        private function _rect(graphics:Graphics, arg:Array):void
        {
            graphics.moveTo(arg[0], arg[1]);
            graphics.lineTo(arg[2], arg[3]);
            graphics.lineTo(arg[4], arg[5]);
            graphics.lineTo(arg[6], arg[7]);
            graphics.lineTo(arg[0], arg[1]);
        }

        private function _arc(graphics:Graphics, arg:Array):void
        {
            var d:Draw = new Draw(graphics, state.transformMatrix);
            d.arc(arg[0], arg[1], arg[2], arg[3], arg[4], arg[5]);
        }

        private function _renderShape():void
        {
            _canvas.bitmapData.draw(shape);
            shape.graphics.clear();
        }

        private function _renderText(text:String, x:Number, y:Number, maxWidth:Number, isStroke:Boolean = false):void
        {
            if (/^\s*$/.test(text))
                return;

            if (!isFinite(x) || !isFinite(y) || isNaN(maxWidth))
                return;

            // If maxWidth is less than or equal to zero, return without doing
            // anything.
            if (maxWidth <= 0)
                return;

            var textFormat:TextFormat = _parseFont();

            var style:Object = isStroke ? state.strokeStyle : state.fillStyle;

            // Set text color
            if (style is CSSColor)
                textFormat.color = style.color;

            // Create TextField object
            var textField:TextField     = new TextField();
            textField.autoSize          = TextFieldAutoSize.LEFT;
            textField.defaultTextFormat = textFormat;
            textField.text              = text.replace(/[\t\n\f\r]/g, " ");

            // Get the size of the text
            var width:int  = textField.textWidth;
            var height:int = textField.textHeight;
            var ascent:int = textField.getLineMetrics(0).ascent;

            // Remove 2px margins around the text
            var matrix:Matrix = new Matrix();
            matrix.translate(-2, -2);

            // Convert the text into BitmapData
            var bitmapData:BitmapData = new BitmapData(width, height, true, 0);
            bitmapData.draw(textField, matrix);

            // Adjust x coordinates
            switch (state.textAlign)
            {
                case "start": if (_canvas.dir == "rtl") x -= width; break;
                case "end": if (_canvas.dir != "rtl") x -= width; break;
                case "left": break;
                case "right": x -= width; break;
                case "center": x -= width / 2; break;
            }

            // Adjust y coordinates
            switch (state.textBaseline)
            {
                case "top":
                case "hanging": break;
                case "middle": y -= height / 2; break;
                case "alphabetic":
                case "ideographic": y -= ascent; break;
                case "bottom": y -= height; break;
            }

            // Create transformation matrix
            matrix = new Matrix();
            matrix.translate(x, y);
            matrix.concat(state.transformMatrix);

            // Calculate alpha multiplier
            var alpha:Number = state.globalAlpha;
            if (style is CSSColor)
                alpha *= style.alpha;

            var colorTransform:ColorTransform = null;
            if (alpha < 1)
            {
                // Make the BitmapData translucent
                colorTransform = new ColorTransform(1, 1, 1, alpha);
            }

            // Render the BitmapData to the Canvas
            _canvas.bitmapData.draw(bitmapData, matrix, colorTransform, null, null, true);

            // Release the memory
            bitmapData.dispose();
        }

        private function _renderImage(bitmapData:BitmapData, args:Array, state:State = null):void
        {
            // Get the drawing state at the time drawImage() was called
            state = state || this.state;

            var sx:Number;
            var sy:Number;
            var sw:Number;
            var sh:Number;
            var dx:Number;
            var dy:Number;
            var dw:Number;
            var dh:Number;

            if (args.length == 8)
            {
                // Define the source and destination rectangles
                sx = args[0];
                sy = args[1];
                sw = args[2];
                sh = args[3];
                dx = args[4];
                dy = args[5];
                dw = args[6];
                dh = args[7];
            }
            else
            {
                // Use whole of the image as a source
                sx = 0;
                sy = 0;
                sw = bitmapData.width;
                sh = bitmapData.height;
                dx = args[0];
                dy = args[1];
                dw = args[2] || sw;
                dh = args[3] || sh;
            }

            // Clip the region within the source rectangle
            var source:BitmapData    = new BitmapData(sw, sh, true, 0);
            var sourceRect:Rectangle = new Rectangle(sx, sy, sw, sh);
            var destPoint:Point      = new Point();
            source.copyPixels(bitmapData, sourceRect, destPoint);

            // Create transformation matrix
            var matrix:Matrix = new Matrix();
            matrix.scale(dw / source.width, dh / source.height);
            matrix.translate(dx, dy);
            matrix.concat(state.transformMatrix);

            var colorTransform:ColorTransform = null;
            if (state.globalAlpha < 1)
            {
                // Make the image translucent
                colorTransform = new ColorTransform(1, 1, 1, state.globalAlpha);
            }

            // Render the image to the Canvas
            _canvas.bitmapData.draw(source, matrix, colorTransform, null, null, true);

            // Release the memory
            source.dispose();
        }
    }
}
