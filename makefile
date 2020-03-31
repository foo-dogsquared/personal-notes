all: build

.PHONY = "build clean setup"
output=.output

build:
	make clean
	./manager.rb compile --directory ./notes

clean:
	rm -rf $(output)

setup:
	gem install asciidoctor slim

%.html : %.adoc
	asciidoctor -T templates/output --attribute toc $< --out-file $(output)/$@

%.pdf : %.adoc
	asciidoctor -r asciidoctor-pdf -b pdf --attribute mathematical-format=svg --attribute toc --attribute 'imagesdir=$(realpath $(output)/$(dir $@))' -r asciidoctor-mathematical $< --out-file $(output)/$@
