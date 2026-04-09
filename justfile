# Build the site via nix
build:
    nix build

# Validate RDF graph parses correctly
validate:
    node -e "const fs=require('fs'); const ox=require('oxigraph'); const s=new ox.Store(); s.load(fs.readFileSync('data/rdf/graph.ttl','utf8'),{format:'text/turtle',base_iri:'https://graph-browser.invalid/'}); console.log('graph.ttl: '+s.size+' triples — OK')"

ci: build validate

# Serve locally
serve: build
    npx serve result -p 10001
