-- | Thin FFI to Cytoscape.js. All graph logic lives
-- | in PureScript; this module only handles rendering.
module FFI.Cytoscape
  ( initCytoscape
  , setElements
  , setFocusElements
  , onNodeTap
  , onNodeHover
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
-- | Edge labels hidden by default.
foreign import setElements
  :: Foreign -> Effect Unit

-- | Replace elements for focus mode.
-- | All edge labels visible.
foreign import setFocusElements
  :: Foreign -> Effect Unit

-- | Register a tap callback on nodes.
foreign import onNodeTap
  :: (String -> Effect Unit) -> Effect Unit

-- | Register a hover (mouseover) callback on nodes.
foreign import onNodeHover
  :: (String -> Effect Unit) -> Effect Unit

-- | Mark a node as the focus root (white border).
foreign import markRoot :: String -> Effect Unit

-- | Clear root marking from all nodes.
foreign import clearRoot :: Effect Unit

-- | Fit the viewport to all elements.
foreign import fitAll :: Effect Unit
