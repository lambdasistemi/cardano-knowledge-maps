-- | Thin FFI to Cytoscape.js. All graph logic lives
-- | in PureScript; this module only handles rendering.
module FFI.Cytoscape
  ( initCytoscape
  , setElements
  , onNodeTap
  , markRoot
  , clearRoot
  , fitAll
  ) where

import Prelude

import Effect (Effect)
import Foreign (Foreign)

-- | Create an empty Cytoscape.js instance in the
-- | given container element.
foreign import initCytoscape
  :: String -> Effect Unit

-- | Replace all elements and re-run layout.
foreign import setElements
  :: Foreign -> Effect Unit

-- | Register a tap callback on nodes.
-- | Receives the node ID.
foreign import onNodeTap
  :: (String -> Effect Unit) -> Effect Unit

-- | Mark a node as the focus root (white border).
foreign import markRoot :: String -> Effect Unit

-- | Clear root marking from all nodes.
foreign import clearRoot :: Effect Unit

-- | Fit the viewport to all elements.
foreign import fitAll :: Effect Unit
