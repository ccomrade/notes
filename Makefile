# Convert Markdown into HTML

.PHONY: all clean

all: Programming.html

%.html: %.md
	pandoc -f markdown -t html -o $@ -s --toc --metadata title=$(basename $@) $<

clean:
	@rm -vf *.html
