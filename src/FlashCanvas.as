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
 * @author Tim Cameron Ryan
 * @author Shinya Muramatsu
 */

package
{
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.external.ExternalInterface;

    import com.googlecode.flashcanvas.Canvas;
    import com.googlecode.flashcanvas.CanvasRenderingContext2D;

    public class FlashCanvas extends Sprite
    {
        private var canvas:Canvas;
        private var context:CanvasRenderingContext2D;
        private var command:Command;

        public function FlashCanvas()
        {
            // stage settings
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align     = StageAlign.TOP_LEFT;
            stage.frameRate = 60;

            ExternalInterface.marshallExceptions = true;
            ExternalInterface.addCallback("postCommands", postCommands);
            ExternalInterface.addCallback("resize", resize);

            // create canvas
            canvas  = new Canvas();
            context = canvas.getContext("2d");
            command = new Command(context);
            addChild(canvas);

            // Remove the prefix "external" from objectID
            var canvasId:String = ExternalInterface.objectID.slice(8);

            // Send JavaScript a message that the swf is ready
            ExternalInterface.call("FlashCanvas.unlock", canvasId, true);
        }

        public function postCommands(data:String):*
        {
            if (data.length > 0)
                return command.parse(data);
            return null;
        }

        public function resize(width:int, height:int):void
        {
            context.resize(width, height);
        }
    }
}
