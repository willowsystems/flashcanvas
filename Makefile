srcdir   = src
bindir   = bin
as3src   = $(srcdir)/FlashCanvas.as
jssrc    = $(srcdir)/flashcanvas.js
swf      = $(bindir)/flashcanvas.swf
js       = $(bindir)/flashcanvas.js
objects  = $(swf) $(js)

# Google Closure Compiler
minifier = compiler.jar

.PHONY: $(swf)

all: $(objects)

$(swf): $(as3src)
	mxmlc -incremental $(as3src) -output $(swf)

$(js): $(jssrc)
	java -jar $(minifier) --compilation_level ADVANCED_OPTIMIZATIONS --externs $(srcdir)/externs.js --js $(jssrc) --js_output_file $(js)

clean:
	rm -f $(objects) $(swf).cache
