var _cy = null;

function hexToRgba(hex, alpha) {
  var r = parseInt(hex.slice(1, 3), 16);
  var g = parseInt(hex.slice(3, 5), 16);
  var b = parseInt(hex.slice(5, 7), 16);
  return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
}

function kindStyles(kinds) {
  var styles = [];
  for (var kind in kinds) {
    var def = kinds[kind];
    styles.push({
      selector: "node." + kind,
      style: {
        "background-color": hexToRgba(def.color, 0.13),
        "border-color": def.color,
        shape: def.shape || "ellipse",
      },
    });
  }
  return styles;
}

function baseStyle(kinds) {
  return [
    {
      selector: "node",
      style: {
        label: "data(label)",
        "text-wrap": "wrap",
        "text-max-width": "140px",
        "font-size": "11px",
        "font-family":
          "-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif",
        color: "#f0f6fc",
        "text-valign": "center",
        "text-halign": "center",
        width: "60px",
        height: "60px",
        "border-width": 2,
        "text-outline-color": "#0d1117",
        "text-outline-width": 2,
      },
    },
    ...kindStyles(kinds),
    {
      selector: "edge",
      style: {
        width: 1.5,
        "line-color": "#30363d",
        "target-arrow-color": "#30363d",
        "target-arrow-shape": "triangle",
        "arrow-scale": 0.8,
        "curve-style": "bezier",
        label: "data(label)",
        "font-size": "11px",
        "font-family":
          "-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif",
        color: "#c9d1d9",
        "text-rotation": "autorotate",
        "text-outline-color": "#0d1117",
        "text-outline-width": 2,
        "text-opacity": 0,
        opacity: 0.6,
      },
    },
    {
      selector: "node.root",
      style: {
        "border-width": 4,
        "border-color": "#f0f6fc",
        "z-index": 10,
      },
    },
    {
      selector: "edge.neighbor",
      style: {
        "text-opacity": 1,
        "line-color": "#8b949e",
        "target-arrow-color": "#8b949e",
        width: 2,
        opacity: 1,
      },
    },
  ];
}

function runLayout(callback) {
  if (!_cy) return;
  var n = _cy.nodes().length;
  var edgeLen = n <= 10 ? 350 : n <= 20 ? 250 : 180;
  var repulsion = n <= 10 ? 50000 : n <= 20 ? 25000 : 8000;
  var sep = n <= 10 ? 250 : n <= 20 ? 180 : 120;
  _cy
    .layout({
      name: "fcose",
      quality: "proof",
      randomize: true,
      animate: true,
      animationDuration: 500,
      fit: true,
      padding: 80,
      nodeSeparation: sep,
      idealEdgeLength: edgeLen,
      edgeElasticity: 0.05,
      nodeRepulsion: repulsion,
      gravity: 0.08,
      gravityRange: 1.2,
      numIter: 5000,
      stop: function () {
        if (callback) callback();
      },
    })
    .run();
}

// kinds is a plain JS object: { "actor": { color, shape }, ... }
export const initCytoscape = (containerId) => (kinds) => () => {
  var container = document.getElementById(containerId);
  if (!container) return;
  if (_cy) {
    _cy.destroy();
    _cy = null;
  }
  _cy = cytoscape({
    container: container,
    elements: [],
    style: baseStyle(kinds),
    layout: { name: "preset" },
    wheelSensitivity: 1,
    minZoom: 0.15,
    maxZoom: 3,
  });
};

export const setElements = (elements) => () => {
  if (!_cy) return;
  _cy.elements().remove();
  _cy.add(elements);
  runLayout();
};

export const setFocusElements = (elements) => () => {
  if (!_cy) return;
  _cy.elements().remove();
  _cy.add(elements);
  runLayout();
  _cy.edges().style("text-opacity", 1);
  _cy.edges().style("opacity", 1);
};

export const onNodeTap = (callback) => () => {
  if (!_cy) return;
  _cy.on("tap", "node", function (evt) {
    callback(evt.target.id())();
  });
};

export const onNodeHover = (callback) => () => {
  if (!_cy) return;
  _cy.on("mouseover", "node", function (evt) {
    callback(evt.target.id())();
  });
};

export const onEdgeHover = (callback) => () => {
  if (!_cy) return;
  _cy.on("mouseover", "edge", function (evt) {
    var d = evt.target.data();
    callback(d.source)(d.target)(d.label || "")(d.description || "")();
  });
};

export const markRoot = (nodeId) => () => {
  if (!_cy) return;
  _cy.nodes().removeClass("root");
  _cy.edges().removeClass("neighbor");
  var node = _cy.getElementById(nodeId);
  if (node.nonempty()) {
    node.addClass("root");
    node.connectedEdges().addClass("neighbor");
  }
};

export const clearRoot = () => {
  if (!_cy) return;
  _cy.nodes().removeClass("root");
  _cy.edges().removeClass("neighbor");
};

export const fitAll = () => {
  if (!_cy) return;
  _cy.animate({ fit: { padding: 60 }, duration: 300 });
};
