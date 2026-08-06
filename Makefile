DRAFT  = draft-signes-jmap-tasklists-00
BUILD  = build/$(DRAFT)
IMAGE  = jmap-tasklists-tools

.PHONY: all xml html txt clean docker-build

all: html txt

docker-build:
	docker build -t $(IMAGE) docker

$(BUILD).xml: $(DRAFT).md
	mkdir -p build
	docker run --rm -v $$(pwd):/work -w /work $(IMAGE) \
	    kramdown-rfc $(DRAFT).md > $(BUILD).xml

$(BUILD).html: $(BUILD).xml
	docker run --rm -v $$(pwd):/work -w /work $(IMAGE) \
	    xml2rfc --html -o $(BUILD).html $(BUILD).xml

$(BUILD).txt: $(BUILD).xml
	docker run --rm -v $$(pwd):/work -w /work $(IMAGE) \
	    xml2rfc --text -o $(BUILD).txt $(BUILD).xml

xml: $(BUILD).xml
html: $(BUILD).html
txt: $(BUILD).txt

clean:
	rm -f $(BUILD).xml $(BUILD).html $(BUILD).txt
