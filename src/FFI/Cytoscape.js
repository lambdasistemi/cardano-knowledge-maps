var _cy = null;

var KIND_COLORS = {
  actor: "#58a6ff",
  "action-type": "#d29922",
  process: "#3fb950",
  mechanism: "#bc8cff",
  artifact: "#f778ba",
  concept: "#79c0ff",
  "param-group": "#e3b341",
  parameter: "#a5d6a7",
  tool: "#56d4dd",
};

function hexToRgba(hex, alpha) {
  var r = parseInt(hex.slice(1, 3), 16);
  var g = parseInt(hex.slice(3, 5), 16);
  var b = parseInt(hex.slice(5, 7), 16);
  return "rgba(" + r + "," + g + "," + b + "," + alpha + ")";
}

var KIND_SHAPES = {
  actor: "ellipse",
  "action-type": "round-rectangle",
  process: "diamond",
  mechanism: "round-hexagon",
  artifact: "rectangle",
  concept: "round-octagon",
  "param-group": "barrel",
  parameter: "round-rectangle",
  tool: "round-pentagon",
};

function kindStyles() {
  var styles = [];
  for (var kind in KIND_COLORS) {
    styles.push({
      selector: "node." + kind,
      style: {
        "background-color": hexToRgba(KIND_COLORS[kind], 0.13),
        "border-color": KIND_COLORS[kind],
        shape: KIND_SHAPES[kind] || "ellipse",
      },
    });
  }
  return styles;
}

var _style = [
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
  ...kindStyles(),
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

function runLayout(callback) {
  if (!_cy) return;
  // Hide edges during layout to prevent overlap warnings
  _cy.edges().style("opacity", 0);
  var opts = {
    fit: true,
    padding: 60,
    animate: true,
    animationDuration: 400,
    stop: function () {
      _cy.edges().style("opacity", "");
      if (callback) callback();
    },
  };
  try {
    _cy
      .layout(
        Object.assign(
          {
            name: "elk",
            elk: {
              algorithm: "layered",
              "elk.direction": "DOWN",
              "elk.spacing.nodeNode": "100",
              "elk.layered.spacing.nodeNodeBetweenLayers": "120",
              "elk.layered.crossingMinimization.strategy": "LAYER_SWEEP",
              "elk.edgeRouting": "SPLINES",
            },
          },
          opts,
        ),
      )
      .run();
  } catch (e) {
    _cy
      .layout(
        Object.assign({ name: "cose", animate: false }, opts),
      )
      .run();
  }
}

export const initCytoscape = (containerId) => () => {
  var container = document.getElementById(containerId);
  if (!container) return;
  if (_cy) {
    _cy.destroy();
    _cy = null;
  }
  _cy = cytoscape({
    container: container,
    elements: [],
    style: _style,
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

// Focus mode: all edge labels visible
export const setFocusElements = (elements) => () => {
  if (!_cy) return;
  _cy.elements().remove();
  _cy.add(elements);
  runLayout();
  // Show all edge labels in focus mode
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
