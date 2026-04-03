module Main where

import Prelude

import Data.Argonaut.Parser (jsonParser)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl, for_)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.String as String
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import FFI.Cytoscape as Cy
import Fetch (Method(..), fetch)
import Graph.Cytoscape as GCy
import Graph.Decode (decodeGraph)
import Graph.Operations (neighborhood, subgraph)
import Data.Argonaut.Decode.Class (decodeJson)
import Data.Argonaut.Decode.Error (printJsonDecodeError)
import Data.Argonaut.Parser as AP
import Graph.Search (SearchResult(..), search)
import Tutorial (Tutorial, TutorialStop, decodeTutorial)
import Graph.Types
  ( Edge
  , Graph
  , Link
  , Node
  , NodeKind(..)
  , emptyGraph
  , kindLabel
  )
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Halogen.VDom.Driver (runUI)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Edge detail shown on hover.
type EdgeInfo =
  { sourceLabel :: String
  , targetLabel :: String
  , label :: String
  , description :: String
  }

-- | Entry in the tutorial index.
type TutorialEntry =
  { id :: String
  , title :: String
  , description :: String
  , file :: String
  }

-- | Application state.
type State =
  { graph :: Graph
  , selected :: Maybe Node
  , hoveredNode :: Maybe Node
  , hoveredEdge :: Maybe EdgeInfo
  , depth :: Int
  , searchQuery :: String
  , searchResults :: Array SearchResult
  , tutorialIndex :: Array TutorialEntry
  , tutorial :: Maybe Tutorial
  , tutorialStep :: Int
  , tutorialActive :: Boolean
  , showTutorialMenu :: Boolean
  , error :: Maybe String
  }

-- | Actions the component can handle.
data Action
  = Initialize
  | NodeTapped String
  | NodeHovered String
  | EdgeHovered String String String String
  | SetDepth Int
  | SetSearch String
  | SelectSearchResult SearchResult
  | FitAll
  | NavigateTo String
  | ToggleTutorialMenu
  | StartTutorial String
  | TutorialNext
  | TutorialPrev
  | TutorialRecenter
  | ExitTutorial

component
  :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ ->
      { graph: emptyGraph
      , selected: Nothing
      , hoveredNode: Nothing
      , hoveredEdge: Nothing
      , depth: 99
      , searchQuery: ""
      , searchResults: []
      , tutorialIndex: []
      , tutorial: Nothing
      , tutorialStep: 0
      , tutorialActive: false
      , showTutorialMenu: false
      , error: Nothing
      }
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div [ cls "app" ]
    [ HH.div [ cls "graph-container" ]
        [ HH.div [ HP.id "cy" ] []
        , renderControls state
        , renderSearchBox state
        , renderLegend
        ]
    , renderSidebar state
    ]

renderControls
  :: forall m. State -> H.ComponentHTML Action () m
renderControls state =
  HH.div [ cls "controls" ]
    [ HH.div [ cls "tour-menu-wrapper" ]
        [ HH.button
            [ cls
                ( "control-btn"
                    <> if state.tutorialActive
                      then " active"
                      else ""
                )
            , HE.onClick \_ ->
                if state.tutorialActive then
                  ExitTutorial
                else ToggleTutorialMenu
            ]
            [ HH.text
                ( if state.tutorialActive then
                    "Exit Tour"
                  else "Guided Tours"
                )
            ]
        , if state.showTutorialMenu then
            renderTutorialMenu state.tutorialIndex
          else HH.text ""
        ]
    , HH.button
        [ cls "control-btn"
        , HE.onClick \_ -> FitAll
        ]
        [ HH.text "Fit View" ]
    , HH.div [ cls "depth-control" ]
        [ HH.span [ cls "depth-label" ]
            [ HH.text "Depth:" ]
        , depthBtn 1 state.depth
        , depthBtn 2 state.depth
        , depthBtn 3 state.depth
        , HH.button
            [ cls
                ( "depth-btn"
                    <> if state.depth >= 99
                      then " active"
                      else ""
                )
            , HE.onClick \_ -> SetDepth 99
            ]
            [ HH.text "All" ]
        ]
    ]

renderTutorialMenu
  :: forall m
   . Array TutorialEntry
  -> H.ComponentHTML Action () m
renderTutorialMenu entries =
  HH.div [ cls "tour-menu" ]
    ( map mkEntry entries )
  where
  mkEntry entry =
    HH.div
      [ cls "tour-menu-item"
      , HE.onClick \_ -> StartTutorial entry.file
      ]
      [ HH.div [ cls "tour-menu-title" ]
          [ HH.text entry.title ]
      , HH.div [ cls "tour-menu-desc" ]
          [ HH.text entry.description ]
      ]

renderSearchBox
  :: forall m. State -> H.ComponentHTML Action () m
renderSearchBox state =
  HH.div [ cls "search-container" ]
    [ HH.input
        [ cls "search-input"
        , HP.type_ HP.InputText
        , HP.placeholder "Search nodes, edges, descriptions..."
        , HP.value state.searchQuery
        , HE.onValueInput SetSearch
        ]
    , if Array.null state.searchResults then
        HH.text ""
      else
        HH.div [ cls "search-results" ]
          (Array.take 12 state.searchResults
            <#> renderSearchResult
          )
    ]

renderSearchResult
  :: forall m
   . SearchResult
  -> H.ComponentHTML Action () m
renderSearchResult result = case result of
  NodeResult node ->
    HH.div
      [ cls "search-result-item"
      , HE.onClick \_ -> SelectSearchResult result
      ]
      [ HH.span
          [ cls ("search-dot"), HP.attr (HH.AttrName "style")
              ("background:" <> kindColor node.kind)
          ]
          []
      , HH.span [ cls "search-result-label" ]
          [ HH.text node.label ]
      , HH.span [ cls "search-result-kind" ]
          [ HH.text (kindLabel node.kind) ]
      ]
  EdgeResult { edge, sourceLabel, targetLabel } ->
    HH.div
      [ cls "search-result-item"
      , HE.onClick \_ -> SelectSearchResult result
      ]
      [ HH.span
          [ cls "search-dot"
          , HP.attr (HH.AttrName "style")
              "background:#8b949e"
          ]
          []
      , HH.span [ cls "search-result-label" ]
          [ HH.text
              (sourceLabel <> " → " <> targetLabel)
          ]
      , HH.span [ cls "search-result-kind" ]
          [ HH.text edge.label ]
      ]

renderSidebar
  :: forall m. State -> H.ComponentHTML Action () m
renderSidebar state =
  HH.div [ cls "sidebar" ]
    [ HH.div [ cls "sidebar-header" ]
        [ HH.h2_ [ HH.text sidebarTitle ]
        ]
    , HH.div [ cls "sidebar-content" ]
        [ if state.tutorialActive then
            renderTutorialContent state
          else case state.hoveredEdge of
            Just edge -> renderEdgeDetail edge
            Nothing -> case state.selected of
              Nothing -> renderEmptyState
              Just node -> renderNodeDetail
                state.graph
                node
        ]
    ]
  where
  sidebarTitle =
    if state.tutorialActive then
      case currentStop state of
        Just stop -> stop.title
        Nothing -> "Tutorial"
    else case state.hoveredEdge of
      Just edge -> edge.label
      Nothing -> case state.selected of
        Nothing -> "Cardano Governance"
        Just n -> n.label

renderEmptyState
  :: forall m. H.ComponentHTML Action () m
renderEmptyState =
  HH.div [ cls "empty-state" ]
    [ HH.h2_
        [ HH.text "Cardano Governance" ]
    , HH.p_
        [ HH.text
            "Hover a node to see details. \
            \Click to re-center."
        ]
    , HH.button
        [ cls "tutorial-start-btn"
        , HE.onClick \_ -> ToggleTutorialMenu
        ]
        [ HH.text "Take a guided tour" ]
    ]

renderTutorialContent
  :: forall m. State -> H.ComponentHTML Action () m
renderTutorialContent state =
  case currentStop state of
    Nothing -> HH.text ""
    Just stop ->
      let
        total = case state.tutorial of
          Just t -> Array.length t.stops
          Nothing -> 0
        stepNum = state.tutorialStep + 1
      in
        HH.div [ cls "tutorial-content" ]
          [ let
              onDetour = case state.selected of
                Just sel -> sel.id /= stop.node
                Nothing -> false
            in
              if onDetour then
                HH.button
                  [ cls "tutorial-nav-btn recenter"
                  , HE.onClick \_ -> TutorialRecenter
                  ]
                  [ HH.text
                      "\x2190 Back to current stop"
                  ]
              else HH.text ""
          , HH.div [ cls "tutorial-progress" ]
              [ HH.text
                  ( show stepNum <> " / "
                      <> show total
                  )
              ]
          , HH.div [ cls "tutorial-narrative" ]
              ( map
                  ( \para ->
                      HH.p [ cls "tutorial-para" ]
                        (parseNarrative para)
                  )
                  (splitParagraphs stop.narrative)
              )
          , HH.div [ cls "tutorial-nav" ]
              [ if state.tutorialStep > 0 then
                  HH.button
                    [ cls "tutorial-nav-btn"
                    , HE.onClick \_ -> TutorialPrev
                    ]
                    [ HH.text "Previous" ]
                else HH.text ""
              , if stepNum < total then
                  HH.button
                    [ cls "tutorial-nav-btn active"
                    , HE.onClick \_ -> TutorialNext
                    ]
                    [ HH.text "Next" ]
                else
                  HH.button
                    [ cls "tutorial-nav-btn"
                    , HE.onClick \_ -> ExitTutorial
                    ]
                    [ HH.text "Finish" ]
              ]
          , HH.button
              [ cls "tutorial-exit"
              , HE.onClick \_ -> ExitTutorial
              ]
              [ HH.text "Exit tour" ]
          , case state.hoveredNode of
              Nothing -> HH.text ""
              Just node ->
                HH.div [ cls "tutorial-hovered-node" ]
                  [ HH.div [ cls "tutorial-hovered-divider" ]
                      []
                  , HH.span
                      [ cls
                          ( "badge badge-"
                              <> show node.kind
                          )
                      ]
                      [ HH.text (kindLabel node.kind)
                      ]
                  , HH.h3 [ cls "tutorial-hovered-label" ]
                      [ HH.text node.label ]
                  , HH.p [ cls "tutorial-hovered-desc" ]
                      [ HH.text node.description ]
                  , if Array.null node.links then
                      HH.text ""
                    else
                      HH.ul [ cls "links" ]
                        ( map
                            ( \l -> HH.li_
                                [ HH.a
                                    [ HP.href l.url
                                    , HP.target "_blank"
                                    , HP.rel "noopener"
                                    ]
                                    [ HH.text l.label
                                    ]
                                ]
                            )
                            node.links
                        )
                  ]
          ]

currentStop :: State -> Maybe TutorialStop
currentStop state = do
  t <- state.tutorial
  Array.index t.stops state.tutorialStep

-- | Parse narrative text with inline links.
-- | Supports [text](node:id) for graph navigation
-- | and [text](https://...) for external links.
parseNarrative
  :: forall m. String -> Array (H.ComponentHTML Action () m)
parseNarrative str = go str []
  where
  go "" acc = Array.reverse acc
  go remaining acc =
    case String.indexOf (String.Pattern "[") remaining of
      Nothing ->
        Array.reverse
          (Array.cons (HH.text remaining) acc)
      Just openBracket ->
        let
          before = String.take openBracket remaining
          rest = String.drop openBracket remaining
        in
          case parseLink rest of
            Nothing ->
              -- Not a valid link, consume the [
              go
                (String.drop 1 rest)
                ( Array.cons
                    (HH.text (before <> "["))
                    acc
                )
            Just { text: linkText, target, consumed } ->
              let
                after = String.drop consumed rest
                beforeEl =
                  if before == "" then []
                  else [ HH.text before ]
                linkEl = case target of
                  NodeTarget nid ->
                    HH.span
                      [ cls "narrative-node-link"
                      , HE.onClick \_ ->
                          NavigateTo nid
                      ]
                      [ HH.text linkText ]
                  ExternalTarget url ->
                    HH.a
                      [ HP.href url
                      , HP.target "_blank"
                      , HP.rel "noopener"
                      , cls "narrative-ext-link"
                      ]
                      [ HH.text linkText ]
              in
                go after
                  ( Array.cons linkEl
                      (beforeEl <> acc)
                  )

data LinkTarget = NodeTarget String | ExternalTarget String

type ParsedLink =
  { text :: String
  , target :: LinkTarget
  , consumed :: Int
  }

parseLink :: String -> Maybe ParsedLink
parseLink str = do
  -- Expect [text](target)
  closeBracket <- String.indexOf
    (String.Pattern "]") str
  let linkText = String.take (closeBracket - 1)
        (String.drop 1 str)
  -- Check for ](
  let afterClose = String.drop (closeBracket + 1) str
  openParen <- case String.indexOf
    (String.Pattern "(") afterClose of
    Just 0 -> Just 0
    _ -> Nothing
  let afterParen = String.drop 1 afterClose
  closeParen <- String.indexOf
    (String.Pattern ")") afterParen
  let targetStr = String.take closeParen afterParen
  let consumed = closeBracket + 1 + 1 + closeParen + 1
  let
    target =
      if String.take 5 targetStr == "node:" then
        NodeTarget (String.drop 5 targetStr)
      else ExternalTarget targetStr
  Just { text: linkText, target, consumed }

splitParagraphs :: String -> Array String
splitParagraphs s =
  Array.filter (_ /= "")
    (splitOn "\n\n" s)

splitOn :: String -> String -> Array String
splitOn sep str = go str []
  where
  sepLen = String.length sep
  go "" acc = Array.reverse acc
  go remaining acc =
    case String.indexOf (String.Pattern sep) remaining of
      Nothing -> Array.reverse (Array.cons remaining acc)
      Just idx ->
        let
          before = String.take idx remaining
          after = String.drop (idx + sepLen) remaining
        in
          go after (Array.cons before acc)

renderEdgeDetail
  :: forall m. EdgeInfo -> H.ComponentHTML Action () m
renderEdgeDetail edge =
  HH.div_
    [ HH.span [ cls "badge badge-mechanism" ]
        [ HH.text "relationship" ]
    , HH.div [ cls "edge-detail" ]
        [ HH.div [ cls "edge-endpoint" ]
            [ HH.span [ cls "edge-role" ]
                [ HH.text "From" ]
            , HH.span [ cls "edge-name" ]
                [ HH.text edge.sourceLabel ]
            ]
        , HH.div [ cls "edge-label" ]
            [ HH.text edge.label ]
        , HH.div [ cls "edge-endpoint" ]
            [ HH.span [ cls "edge-role" ]
                [ HH.text "To" ]
            , HH.span [ cls "edge-name" ]
                [ HH.text edge.targetLabel ]
            ]
        ]
    , HH.p [ cls "description" ]
        [ HH.text edge.description ]
    ]

renderNodeDetail
  :: forall m
   . Graph
  -> Node
  -> H.ComponentHTML Action () m
renderNodeDetail graph node =
  HH.div_
    [ HH.span
        [ cls ("badge badge-" <> show node.kind) ]
        [ HH.text (kindLabel node.kind) ]
    , HH.p [ cls "description" ]
        [ HH.text node.description ]
    , renderLinks node.links
    , renderConnections "Connects to" outEdges
    , renderConnections "Connected from" inEdges
    ]
  where
  outEdges = Array.filter
    (\e -> e.source == node.id)
    graph.edges
  inEdges = Array.filter
    (\e -> e.target == node.id)
    graph.edges

  renderLinks
    :: Array Link -> H.ComponentHTML Action () m
  renderLinks [] = HH.text ""
  renderLinks links =
    HH.ul [ cls "links" ]
      ( map
          ( \l -> HH.li_
              [ HH.a
                  [ HP.href l.url
                  , HP.target "_blank"
                  , HP.rel "noopener"
                  ]
                  [ HH.text l.label ]
              ]
          )
          links
      )

  renderConnections
    :: String
    -> Array Edge
    -> H.ComponentHTML Action () m
  renderConnections _ [] = HH.text ""
  renderConnections title edges =
    HH.div [ cls "connections" ]
      [ HH.h3_ [ HH.text title ]
      , HH.div_ (map mkConn edges)
      ]

  mkConn :: Edge -> H.ComponentHTML Action () m
  mkConn edge =
    let
      targetId =
        if edge.source == node.id then edge.target
        else edge.source
      targetNode = Map.lookup targetId graph.nodes
      targetLabel = case targetNode of
        Just n -> n.label
        Nothing -> targetId
    in
      HH.div
        [ cls "connection-item"
        , HE.onClick \_ -> NavigateTo targetId
        ]
        [ HH.span [ cls "conn-label" ]
            [ HH.text edge.label ]
        , HH.span [ cls "conn-node" ]
            [ HH.text targetLabel ]
        ]

renderLegend :: forall m. H.ComponentHTML Action () m
renderLegend =
  HH.div [ cls "legend" ]
    [ HH.text
        "Hover to inspect. Click to \
        \re-center. "
    , HH.a
        [ HP.href
            "https://github.com/lambdasistemi\
            \/cardano-governance-graph"
        , HP.target "_blank"
        , HP.rel "noopener"
        , cls "legend-link"
        ]
        [ HH.text "Source" ]
    ]

handleAction
  :: forall o
   . Action
  -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
  Initialize -> do
    liftEffect $ Cy.initCytoscape "cy"
    tapSub <- liftEffect HS.create
    liftEffect $ Cy.onNodeTap \nodeId ->
      HS.notify tapSub.listener
        (NodeTapped nodeId)
    void $ H.subscribe tapSub.emitter
    hoverSub <- liftEffect HS.create
    liftEffect $ Cy.onNodeHover \nodeId ->
      HS.notify hoverSub.listener
        (NodeHovered nodeId)
    void $ H.subscribe hoverSub.emitter
    edgeSub <- liftEffect HS.create
    liftEffect $ Cy.onEdgeHover
      \src tgt lbl desc ->
        HS.notify edgeSub.listener
          (EdgeHovered src tgt lbl desc)
    void $ H.subscribe edgeSub.emitter
    result <- liftAff loadGraphData
    case result of
      Left err ->
        H.modify_ _ { error = Just err }
      Right graph -> do
        let start = mostConnectedNode graph
        H.modify_ _
          { graph = graph
          , selected = start
          }
        renderGraph
    -- Load tutorial index
    idxResult <- liftAff loadTutorialIndex
    case idxResult of
      Left _ -> pure unit
      Right idx ->
        H.modify_ _ { tutorialIndex = idx }

  NodeTapped nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    renderGraph

  NodeHovered nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    if state.tutorialActive then
      -- In tutorial mode: show node below tutorial text
      H.modify_ _
        { hoveredNode = node, hoveredEdge = Nothing }
    else
      -- Normal mode: update selected node
      H.modify_ _
        { selected = node, hoveredEdge = Nothing }
    liftEffect $ Cy.markRoot nodeId

  EdgeHovered srcId tgtId lbl desc -> do
    state <- H.get
    let
      srcNode = Map.lookup srcId state.graph.nodes
      tgtNode = Map.lookup tgtId state.graph.nodes
      srcLabel = case srcNode of
        Just n -> n.label
        Nothing -> srcId
      tgtLabel = case tgtNode of
        Just n -> n.label
        Nothing -> tgtId
    H.modify_ _
      { hoveredNode = Nothing
      , hoveredEdge = Just
          { sourceLabel: srcLabel
          , targetLabel: tgtLabel
          , label: lbl
          , description: desc
          }
      , selected = Nothing
      }

  SetDepth d -> do
    H.modify_ _ { depth = d }
    renderGraph

  SetSearch q -> do
    state <- H.get
    let results = search q state.graph
    H.modify_ _
      { searchQuery = q
      , searchResults = results
      }

  SelectSearchResult result -> do
    state <- H.get
    case result of
      NodeResult node -> do
        H.modify_ _
          { selected = Just node
          , searchQuery = ""
          , searchResults = []
          , hoveredEdge = Nothing
          }
        renderGraph
      EdgeResult { edge, sourceLabel, targetLabel } ->
        do
          let
            node = Map.lookup edge.source
              state.graph.nodes
          H.modify_ _
            { selected = node
            , hoveredEdge = Just
                { sourceLabel
                , targetLabel
                , label: edge.label
                , description: edge.description
                }
            , searchQuery = ""
            , searchResults = []
            }
          renderGraph

  FitAll ->
    liftEffect Cy.fitAll

  ToggleTutorialMenu ->
    H.modify_ \s -> s
      { showTutorialMenu = not s.showTutorialMenu }

  StartTutorial file -> do
    result <- liftAff (loadTutorialFile file)
    case result of
      Left _ -> pure unit
      Right tut -> do
        H.modify_ _
          { tutorial = Just tut
          , tutorialStep = 0
          , tutorialActive = true
          , showTutorialMenu = false
          }
        applyTutorialStop

  TutorialNext -> do
    state <- H.get
    case state.tutorial of
      Just t ->
        when
          ( state.tutorialStep
              < Array.length t.stops - 1
          )
          do
            H.modify_ \s -> s
              { tutorialStep = s.tutorialStep + 1
              }
            applyTutorialStop
      Nothing -> pure unit

  TutorialPrev -> do
    state <- H.get
    when (state.tutorialStep > 0) do
      H.modify_ \s -> s
        { tutorialStep = s.tutorialStep - 1 }
      applyTutorialStop

  TutorialRecenter ->
    applyTutorialStop

  ExitTutorial -> do
    H.modify_ _
      { tutorialActive = false
      , depth = 99
      , hoveredNode = Nothing
      }
    renderGraph

  NavigateTo nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    renderGraph

renderGraph
  :: forall o
   . H.HalogenM State Action () o Aff Unit
renderGraph = do
  state <- H.get
  let
    visible = case state.selected of
      Just node ->
        let
          hood = neighborhood state.depth
            node.id
            state.graph
        in
          subgraph hood state.graph
      Nothing -> state.graph

  liftEffect $ Cy.setFocusElements
    (GCy.toElements visible)
  for_ state.selected \node ->
    liftEffect $ Cy.markRoot node.id

-- | Find the node with the most connections.
mostConnectedNode :: Graph -> Maybe Node
mostConnectedNode graph =
  let
    edges = graph.edges
    counts = foldl countEdge Map.empty edges
    best = foldl
      ( \acc (Tuple nid count) ->
          case acc of
            Nothing -> Just (Tuple nid count)
            Just (Tuple _ best') ->
              if count > best'
                then Just (Tuple nid count)
                else acc
      )
      Nothing
      (Map.toUnfoldable counts :: Array _)
  in
    case best of
      Just (Tuple nid _) ->
        Map.lookup nid graph.nodes
      Nothing -> Nothing
  where
  countEdge m edge =
    let
      m1 = Map.alter (Just <<< add 1 <<< orZero) edge.source m
      m2 = Map.alter (Just <<< add 1 <<< orZero) edge.target m1
    in
      m2
  orZero Nothing = 0
  orZero (Just n) = n

applyTutorialStop
  :: forall o
   . H.HalogenM State Action () o Aff Unit
applyTutorialStop = do
  state <- H.get
  case currentStop state of
    Nothing -> pure unit
    Just stop -> do
      let node = Map.lookup stop.node state.graph.nodes
      H.modify_ _
        { selected = node
        , depth = stop.depth
        , hoveredEdge = Nothing
        }
      renderGraph

loadTutorialIndex :: Aff (Either String (Array TutorialEntry))
loadTutorialIndex = do
  resp <- fetch "data/tutorials/index.json"
    { method: GET }
  body <- resp.text
  pure case AP.jsonParser body of
    Left err -> Left err
    Right json -> lmapShow $ decodeJson json

loadTutorialFile :: String -> Aff (Either String Tutorial)
loadTutorialFile file = do
  resp <- fetch file { method: GET }
  body <- resp.text
  pure case AP.jsonParser body of
    Left err -> Left err
    Right json -> decodeTutorial json

loadGraphData :: Aff (Either String Graph)
loadGraphData = do
  resp <- fetch "data/graph.json" { method: GET }
  body <- resp.text
  pure case jsonParser body of
    Left err -> Left err
    Right json -> decodeGraph json

-- Helpers

depthBtn
  :: forall m
   . Int
  -> Int
  -> H.ComponentHTML Action () m
depthBtn n current =
  HH.button
    [ cls
        ( "depth-btn"
            <> if n == current then " active"
              else ""
        )
    , HE.onClick \_ -> SetDepth n
    ]
    [ HH.text (show n) ]

lmapShow :: forall a. Either _ a -> Either String a
lmapShow (Left e) = Left (printJsonDecodeError e)
lmapShow (Right a) = Right a

cls
  :: forall r i
   . String
  -> HH.IProp (class :: String | r) i
cls = HP.class_ <<< HH.ClassName

kindColor :: NodeKind -> String
kindColor Actor = "#58a6ff"
kindColor ActionType = "#d29922"
kindColor Process = "#3fb950"
kindColor Mechanism = "#bc8cff"
kindColor Artifact = "#f778ba"
kindColor Concept = "#79c0ff"
kindColor ParamGroup = "#e3b341"
kindColor Parameter = "#a5d6a7"
kindColor Tool = "#56d4dd"
