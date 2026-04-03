browser_url := "https://lambdasistemi.github.io/graph-browser"

# Fetch the graph browser app bundle
fetch-browser:
    curl -sL {{browser_url}}/index.html -o dist/index.html
    curl -sL {{browser_url}}/index.js -o dist/index.js

# Copy data into dist for deployment
prepare: fetch-browser
    rm -rf dist/data
    cp -r data dist/data

# Validate graph data
validate:
    node -e "const d=require('./data/graph.json'); const ids=new Set(d.nodes.map(n=>n.id)); d.edges.forEach((e,i)=>{if(!ids.has(e.source))console.error('BAD source e'+i+': '+e.source);if(!ids.has(e.target))console.error('BAD target e'+i+': '+e.target)}); console.log(d.nodes.length+' nodes, '+d.edges.length+' edges — OK')"

ci: validate

# Serve locally
serve: prepare
    npx serve dist -p 10001

clean:
    rm -rf dist/index.js dist/index.html dist/data
