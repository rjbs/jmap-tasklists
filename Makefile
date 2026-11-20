# The source file is unversioned.  The versioned name of the draft comes from
# the "docname" in its front matter, and the build products are named for it.
SRC    := $(wildcard draft-*.md)
DRAFT  := $(shell sed -n 's/^docname: *//p' $(SRC))
BUILD  = build/$(DRAFT)
IMAGE  = jmap-tasklists-tools

.PHONY: all xml html txt clean docker-build print-draft

all: html txt

docker-build:
	docker build -t $(IMAGE) docker

$(BUILD).xml: $(SRC)
	mkdir -p build
	docker run --rm -v $$(pwd):/work -w /work $(IMAGE) \
	    kramdown-rfc $(SRC) > $(BUILD).xml

$(BUILD).html: $(BUILD).xml
	docker run --rm -v $$(pwd):/work -w /work $(IMAGE) \
	    xml2rfc --html -o $(BUILD).html $(BUILD).xml

$(BUILD).txt: $(BUILD).xml
	docker run --rm -v $$(pwd):/work -w /work $(IMAGE) \
	    xml2rfc --text -o $(BUILD).txt $(BUILD).xml

xml: $(BUILD).xml
html: $(BUILD).html
txt: $(BUILD).txt

print-draft:
	@echo $(DRAFT)

clean:
	rm -f $(BUILD).xml $(BUILD).html $(BUILD).txt
