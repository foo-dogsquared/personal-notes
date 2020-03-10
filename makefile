all: build

.PHONY = "build clean"
output=.output

build:
	make clean
	./manager.py compile ./notes --threadcount 16

clean:
	rm -rf $(output)

%.html : %.adoc
	asciidoctor -T .templates --attribute toc $< --out-file $(output)/$@

%.pdf : %.adoc
	asciidoctor -r asciidoctor-pdf -b pdf --attribute mathematical-format=svg --attribute toc --attribute 'imagesdir=$(realpath $(output)/$(dir $@))' -r asciidoctor-mathematical $< --out-file $(output)/$@
