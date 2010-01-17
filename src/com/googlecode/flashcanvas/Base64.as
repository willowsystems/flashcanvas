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
 * @author Shinya Muramatsu
 */

package com.googlecode.flashcanvas
{
    import flash.utils.ByteArray;

    public class Base64
    {
        private static var CHARS:Array =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".split("");

        public static function encode(input:ByteArray):String
        {
            var output:Array = [];
            var i:uint = 0;
            var j:uint = 0;
            var length:uint = input.length;

            while (i < length)
            {
                var n:uint = input[i++] << 16 | input[i++] << 8 | input[i++];
                output[j++] = CHARS[n >> 18];
                output[j++] = CHARS[n >> 12 & 63];
                output[j++] = CHARS[n >>  6 & 63];
                output[j++] = CHARS[n & 63];
            }

            switch (length % 3)
            {
                case 1: output[j - 2] = "=";
                case 2: output[j - 1] = "=";
            }

            return output.join("");
        }
    }
}
