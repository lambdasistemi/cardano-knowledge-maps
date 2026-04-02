-- | Core types for the governance knowledge graph.
module Graph.Types
  ( NodeId
  , NodeKind(..)
  , allKinds
  , kindLabel
  , Link
  , Node(..)
  , Edge(..)
  , Graph(..)
  , emptyGraph
  ) where

import Prelude

import Data.Argonaut.Core (fromString, toString)
import Data.Argonaut.Decode.Class (class DecodeJson)
import Data.Argonaut.Decode.Error (JsonDecodeError(..))
import Data.Argonaut.Encode.Class (class EncodeJson)
import Data.Either (note)
import Data.Map (Map)
import Data.Map as Map
import Data.Set (Set)

-- | Unique identifier for a node.
type NodeId = String

-- | Classification of a node by governance role.
data NodeKind
  = Actor
  | ActionType
  | Process
  | Mechanism
  | Artifact
  | Concept
  | ParamGroup
  | Parameter
  | Tool

derive instance eqNodeKind :: Eq NodeKind
derive instance ordNodeKind :: Ord NodeKind

instance showNodeKind :: Show NodeKind where
  show Actor = "actor"
  show ActionType = "action-type"
  show Process = "process"
  show Mechanism = "mechanism"
  show Artifact = "artifact"
  show Concept = "concept"
  show ParamGroup = "param-group"
  show Parameter = "parameter"
  show Tool = "tool"

-- | All node kinds in display order.
allKinds :: Array NodeKind
allKinds =
  [ Actor
  , ActionType
  , Process
  , Mechanism
  , Artifact
  , Concept
  , ParamGroup
  , Parameter
  , Tool
  ]

-- | Human-readable label for a kind.
kindLabel :: NodeKind -> String
kindLabel Actor = "Actor"
kindLabel ActionType = "Action Type"
kindLabel Process = "Process"
kindLabel Mechanism = "Mechanism"
kindLabel Artifact = "Artifact"
kindLabel Concept = "Concept"
kindLabel ParamGroup = "Param Group"
kindLabel Parameter = "Parameter"
kindLabel Tool = "Tool"

parseKind :: String -> NodeKind
parseKind "actor" = Actor
parseKind "action-type" = ActionType
parseKind "process" = Process
parseKind "mechanism" = Mechanism
parseKind "artifact" = Artifact
parseKind "concept" = Concept
parseKind "param-group" = ParamGroup
parseKind "parameter" = Parameter
parseKind "tool" = Tool
parseKind _ = Concept

instance encodeJsonNodeKind :: EncodeJson NodeKind where
  encodeJson = show >>> fromString

instance decodeJsonNodeKind :: DecodeJson NodeKind where
  decodeJson json =
    note (TypeMismatch "NodeKind") (toString json)
      <#> parseKind

-- | An external link associated with a node.
type Link =
  { label :: String
  , url :: String
  }

-- | A node in the governance graph.
type Node =
  { id :: NodeId
  , label :: String
  , kind :: NodeKind
  , group :: String
  , description :: String
  , links :: Array Link
  }

-- | A directed edge in the governance graph.
type Edge =
  { source :: NodeId
  , target :: NodeId
  , label :: String
  }

-- | The full graph: nodes, edges, and adjacency.
type Graph =
  { nodes :: Map NodeId Node
  , edges :: Array Edge
  , forward :: Map NodeId (Set NodeId)
  , backward :: Map NodeId (Set NodeId)
  }

-- | An empty graph.
emptyGraph :: Graph
emptyGraph =
  { nodes: Map.empty
  , edges: []
  , forward: Map.empty
  , backward: Map.empty
  }
