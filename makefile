all: build

output=.output

build: compile.py
	./compile.py --threadcount 8

clean: .output/
	rm -rf $(output)

%.html : %.adoc
	asciidoctor --attribute toc $< --out-file $(output)/$@
