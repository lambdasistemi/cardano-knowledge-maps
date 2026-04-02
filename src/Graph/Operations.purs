-- | Pure graph operations: neighborhood extraction,
-- | filtering, subgraph construction.
module Graph.Operations
  ( neighborhood
  , subgraph
  ) where

import Prelude

import Data.Array as Array
import Data.Foldable (foldl)
import Data.Map as Map
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Graph.Build (buildGraph)
import Graph.Types (Graph, NodeId)

-- | Collect all node IDs reachable within n hops
-- | (both forward and backward) from a root node.
neighborhood :: Int -> NodeId -> Graph -> Set NodeId
neighborhood depth root graph = go depth (Set.singleton root)
  where
  go 0 visited = visited
  go n visited =
    let
      newNeighbors = foldl
        ( \acc nid ->
            let
              fwd = fromMaybe Set.empty
                (Map.lookup nid graph.forward)
              bwd = fromMaybe Set.empty
                (Map.lookup nid graph.backward)
            in
              Set.union acc
                (Set.union fwd bwd)
        )
        Set.empty
        visited
      expanded = Set.union visited newNeighbors
    in
      if expanded == visited then visited
      else go (n - 1) expanded

-- | Extract a subgraph containing only the given
-- | node IDs and their connecting edges.
subgraph :: Set NodeId -> Graph -> Graph
subgraph keep graph =
  buildGraph keptNodes keptEdges
  where
  keptNodes = Array.filter
    (\n -> Set.member n.id keep)
    (Array.fromFoldable (Map.values graph.nodes))

  keptEdges = Array.filter
    ( \e ->
        Set.member e.source keep
          && Set.member e.target keep
    )
    graph.edges
