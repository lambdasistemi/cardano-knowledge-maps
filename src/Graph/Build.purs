-- | Build a Graph from raw nodes and edges.
module Graph.Build
  ( buildGraph
  ) where

import Prelude

import Data.Foldable (foldl)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set as Set
import Graph.Types (Edge, Graph, Node)

-- | Construct a graph with adjacency maps from
-- | arrays of nodes and edges.
buildGraph :: Array Node -> Array Edge -> Graph
buildGraph nodes edges =
  { nodes: nodeMap
  , edges
  , forward: fwd
  , backward: bwd
  }
  where
  nodeMap = foldl
    (\m n -> Map.insert n.id n m)
    Map.empty
    nodes

  fwd = foldl
    ( \m e ->
        Map.alter
          ( \existing ->
              Just
                ( Set.insert e.target
                    (fromMaybe Set.empty existing)
                )
          )
          e.source
          m
    )
    Map.empty
    edges

  bwd = foldl
    ( \m e ->
        Map.alter
          ( \existing ->
              Just
                ( Set.insert e.source
                    (fromMaybe Set.empty existing)
                )
          )
          e.target
          m
    )
    Map.empty
    edges
