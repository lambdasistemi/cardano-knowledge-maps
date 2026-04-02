-- | Convert a Graph to Cytoscape.js JSON elements.
module Graph.Cytoscape
  ( toElements
  ) where

import Prelude

import Data.Array as Array
import Data.Map as Map
import Foreign (Foreign, unsafeToForeign)
import Graph.Types (Edge, Graph, Node)

-- | Convert a graph to a Cytoscape.js elements
-- | array (Foreign).
toElements :: Graph -> Foreign
toElements graph = unsafeToForeign
  (nodeEls <> edgeEls)
  where
  allNodes = Array.fromFoldable
    (Map.values graph.nodes)

  nodeEls = map mkNodeEl allNodes

  edgeEls = Array.mapWithIndex mkEdgeEl graph.edges

mkNodeEl :: Node -> Foreign
mkNodeEl node = unsafeToForeign
  { group: "nodes"
  , data:
      { id: node.id
      , label: node.label
      , kind: show node.kind
      , nodeGroup: node.group
      }
  , classes: show node.kind
  }

mkEdgeEl :: Int -> Edge -> Foreign
mkEdgeEl i edge = unsafeToForeign
  { group: "edges"
  , data:
      { id: "e" <> show i
      , source: edge.source
      , target: edge.target
      , label: edge.label
      }
  }
