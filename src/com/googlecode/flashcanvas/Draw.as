/*
 * FlashCanvas
 *
 * Copyright (c) 2009      Shinya Muramatsu
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
 * @author Shinya Muramatsu
 * @see    http://code.google.com/p/ascanvas/
 */

package com.googlecode.flashcanvas
{
    import flash.display.Graphics;
    import flash.geom.Matrix;
    import flash.geom.Point;

    public class Draw
    {
        private var graphics:Graphics;
        private var matrix:Matrix;

        public function Draw(graphics:Graphics, matrix:Matrix)
        {
            this.graphics = graphics;
            this.matrix   = matrix;
        }

        public function arc(cx:Number, cy:Number, radius:Number, startAngle:Number, endAngle:Number, clockwise:Boolean):void
        {
            startAngle *= 180 / Math.PI;
            endAngle   *= 180 / Math.PI;

            if (endAngle < 0)
                endAngle += 360;

            var arc:Number = endAngle - startAngle;
            if (clockwise)
            {
                arc = 360 - arc;
                if (arc == 0 && endAngle != startAngle)
                    arc = 360;
            }
            if (Math.abs(arc) > 360)
                arc = 360;

            var segs:Number = Math.ceil(Math.abs(arc) / 45);
            var segAngle:Number = arc / segs;

            var angle:Number = (startAngle / 180) * Math.PI;
            var theta:Number = (segAngle / 180) * Math.PI;
            if (clockwise)
                theta = -theta;

            var angleMid:Number;
            var radiusMid:Number = radius / Math.cos(theta / 2);
            var dx:Number;
            var dy:Number;
            var diff:Point;
            var bx:Number;
            var by:Number;
            var ctlx:Number;
            var ctly:Number;

            for (var i:int = 0; i < segs; i++)
            {
                angle += theta;
                angleMid = angle - (theta / 2);

                dx = Math.cos(angle) * radius;
                dy = Math.sin(angle) * radius;
                diff = matrix.deltaTransformPoint(new Point(dx, dy));
                bx = cx + diff.x;
                by = cy + diff.y;

                dx = Math.cos(angleMid) * radiusMid;
                dy = Math.sin(angleMid) * radiusMid;
                diff = matrix.deltaTransformPoint(new Point(dx, dy));
                ctlx = cx + diff.x;
                ctly = cy + diff.y;

                graphics.curveTo(ctlx, ctly, bx, by);
            }
        }
    }
}
