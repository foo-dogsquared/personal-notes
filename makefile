all: build

.PHONY = "build clean"
output=.output

build:
	make clean
	./manager.py compile --threadcount 16

clean:
	rm -rf $(output)

%.html : %.adoc
	asciidoctor --attribute toc $< --out-file $(output)/$@

%.pdf : %.adoc
	asciidoctor --attribute toc $< --backend pdf --out-file $(output)/$@