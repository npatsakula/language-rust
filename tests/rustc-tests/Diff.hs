{-# OPTIONS_GHC -Wall -Wno-orphans #-}
{-# LANGUAGE OverloadedStrings, OverloadedLists, InstanceSigs #-}
module Diff where

import Data.Aeson
import Language.Rust.Syntax

import Control.Monad (when)

import Data.String (fromString)
import Data.List.NonEmpty ((<|))
import Data.Maybe (fromMaybe, isNothing)
import Data.Semigroup ((<>))
import qualified Data.Text as T
import qualified Data.Vector as V

import DiffUtils

instance Show a => Diffable (SourceFile a) where
  SourceFile _ as is === val = do
    -- Check attributes
    as === (val ! "attrs")
   
    -- Check items
    is === (val ! "module" ! "items")

instance Show a => Diffable (Item a) where
  item@(Item i as n v _) === val = do
    -- Check name of item
    when (fromString (show i) /= val ! "ident") $
      diff "item has different name" item val
   
    -- Check attributes
    as === (val ! "attrs")
    
    -- Check node
    let n' = val ! "node"
    case (n' ! "variant", n) of
      ("Fn", Fn decl u c a gen bod) -> do
        decl === (n' ! "fields" ! 0)
        u    === (n' ! "fields" ! 1)
        c    === (n' ! "fields" ! 2)
        a    === (n' ! "fields" ! 3)
        gen  === (n' ! "fields" ! 4)
        bod  === (n' ! "fields" ! 5)
      ("ExternCrate", ExternCrate Nothing) -> pure ()
      ("ExternCrate", ExternCrate (Just (Ident i' _))) -> 
        when (n' ! "fields" ! 0 /= String (fromString i')) $
          diff "different crate import" item val
      ("Use", Use v') ->
        v' === (n' ! "fields" ! 0)
      ("Static", Static t m e) -> do
        t === (n' ! "fields" ! 0)
        m === (n' ! "fields" ! 1)
        e === (n' ! "fields" ! 2)
      ("Const", ConstItem t e) -> do
        t === (n' ! "fields" ! 0)
        e === (n' ! "fields" ! 1)
      ("Mod", Mod is) ->
        is === (n' ! "fields" ! 0 ! "items")
      ("ForeignMod", ForeignMod a is) -> do
        a === (n' ! "fields" ! 0 ! "abi")
        is === (n' ! "fields" ! 0 ! "items")
      ("Ty", TyAlias t g) -> do
        t === (n' ! "fields" ! 0)
        g === (n' ! "fields" ! 1)
      ("Enum", Enum vs g) -> do
        vs === (n' ! "fields" ! 0 ! "variants") 
        g === (n' ! "fields" ! 1)
      ("Struct", StructItem v' g) ->  do
        v' === (n' ! "fields" ! 0)
        g === (n' ! "fields" ! 1)
      ("Union", Union v' g) ->  do
        v' === (n' ! "fields" ! 0)
        g === (n' ! "fields" ! 1)
      ("Trait", Trait u g bd is) -> do
        u === (n' ! "fields" ! 0)
        g === (n' ! "fields" ! 1)
        bd === (n' ! "fields" ! 2)
        is === (n' ! "fields" ! 3)
      ("DefaultImpl", DefaultImpl u tr) -> do
        u === (n' ! "fields" ! 0)
        tr === (n' ! "fields" ! 1)
      ("Impl", Impl u p g mtr t is) -> do 
        u === (n' ! "fields" ! 0)
        p === (n' ! "fields" ! 1)
        g === (n' ! "fields" ! 2)
        mtr === (n' ! "fields" ! 3)
        t === (n' ! "fields" ! 4)
        is === (n' ! "fields" ! 5)
      ("Mac", MacItem m) ->
        m === (n' ! "fields" ! 0)
      
      _ -> diff "different items" item val
  
    -- Check visibility
    v === (val ! "vis")

instance Diffable ImplPolarity where
  Positive === "Positive" = pure ()
  Negative === "Negative" = pure ()
  p        === val = diff "different polarity" p val

instance Show a => Diffable (TraitItem a) where
  item@(TraitItem i as n _) === val = do
    as === (val ! "attrs")
    i === (val ! "ident")
    
    let n' = val ! "node"
    case (n' ! "variant", n) of
      ("Const", ConstT t me) -> do
        t === (n' ! "fields" ! 0)
        me ===(n' ! "fields" ! 1)
      ("Method", MethodT m mb) -> do
        m === (n' ! "fields" ! 0)
        mb === (n' ! "fields" ! 1)
      ("Type", TypeT bd mt) -> do
        bd === (n' ! "fields" ! 0)
        mt === (n' ! "fields" ! 1)
      ("Macro", MacroT m) ->
        m === (n' ! "fields" ! 0)
      _ -> diff "different trait item" item val

instance Show a => Diffable (ImplItem a) where
  item@(ImplItem i v d as n _) === val = do
    as === (val ! "attrs")
    i === (val ! "ident")
    v === (val ! "vis")
    d === (val ! "defaultness")
    
    let n' = val ! "node"
    case (n' ! "variant", n) of
      ("Const", ConstI t e) -> do
        t === (n' ! "fields" ! 0)
        e ===(n' ! "fields" ! 1)
      ("Method", MethodI m b) -> do
        m === (n' ! "fields" ! 0)
        b === (n' ! "fields" ! 1)
      ("Type", TypeI t) ->
        t === (n' ! "fields" ! 0)
      ("Macro", MacroI m) ->
        m === (n' ! "fields" ! 0)
      _ -> diff "different impl item" item val
      
instance Show a => Diffable (MethodSig a) where
  MethodSig u c a decl g === val = do
    u === (val ! "unsafety")
    a === (val ! "abi")
    g === (val ! "generics")
    c === (val ! "constness")
    decl === (val ! "decl")

instance Diffable Defaultness where
  Final   === "Final" = pure ()
  Default === "Default" = pure ()
  d       === val = diff "different defaultness" d val

instance Show a => Diffable (Variant a) where
  Variant i as d e _ === val = do
    i === (val ! "node" ! "name")
    as === (val ! "node" ! "attrs")
    d === (val ! "node" ! "data")
    e === (val ! "node" ! "disr_expr")

instance Show a => Diffable (VariantData a) where
  d === val =
    case (val ! "variant", d) of
      ("Tuple", TupleD sf _) -> sf === (val ! "fields" ! 0) 
      ("Struct", StructD sf _) -> sf === (val ! "fields" ! 0)
      ("Unit", UnitD _) -> pure ()
      _ -> diff "different variants" d val

instance Show a => Diffable (StructField a) where
  StructField i v t as _ === val = do
    i === (val ! "ident")
    v === (val ! "vis")
    t === (val ! "ty")
    as === (val ! "attrs")

instance Show a => Diffable (ForeignItem a) where
  f@(ForeignItem i as n v _) === val = do
    i === (val ! "ident")
    as === (val ! "attrs")
    v === (val ! "vis")
    let n' = val ! "node"
    case (n' ! "variant", n) of
      ("Fn", ForeignFn d g) -> do
        d === (n' ! "fields" ! 0) 
        g === (n' ! "fields" ! 1)
      ("Static", ForeignStatic t m) -> do
        t === (n' ! "fields" ! 0)
        m === (n' ! "fields" ! 1)
      _ -> diff "different foreign item" f val

instance Show a => Diffable (ViewPath a) where
  v === val = do
    let n' = val ! "node"
    case (n' ! "variant", v) of
      ("ViewPathGlob", ViewPathGlob g is _) -> do
        v' <- jsonDrop (if g || glbl is then 1 else 0) (n' ! "fields" ! 0 ! "segments")
        map ViewPathIdent is === v' 
      ("ViewPathList", ViewPathList g is pl _) -> do
        v' <- jsonDrop (if g || glbl is then 1 else 0) (n' ! "fields" ! 0 ! "segments")
        map ViewPathIdent is === v' 
        pl === (n' ! "fields" ! 1)
      ("ViewPathSimple", ViewPathSimple g is (PathListItem n (Just r) _) _) -> do
        r === (n' ! "fields" ! 0)
        v' <- jsonDrop (if g || glbl is then 1 else 0) (n' ! "fields" ! 1 ! "segments")
        map ViewPathIdent (is ++ [n]) === v' 
      ("ViewPathSimple", ViewPathSimple g is (PathListItem n Nothing _) _) -> do
        n === (n' ! "fields" ! 0)
        v' <- jsonDrop (if g || glbl is then 1 else 0) (n' ! "fields" ! 1 ! "segments")
        map ViewPathIdent (is ++ [n]) === v' 
      _ -> diff "different view path" v val
    where
    
    glbl :: [Ident] -> Bool
    glbl (Ident "self" _ : _) = False
    glbl (Ident "super" _ : _) = False
    glbl _ = True

    jsonDrop :: Int -> Value -> IO Value
    jsonDrop i (Data.Aeson.Array v') = pure $ Data.Aeson.Array (V.drop i v')
    jsonDrop i val' = diff "cannot use 'jsonDrop' on non-array" i val'

newtype ViewPathIdent = ViewPathIdent Ident deriving (Show)

instance Diffable ViewPathIdent where
  ViewPathIdent i === val = do
      when (Null /= val ! "parameters") $
        diff "view path identifier has parameters" i val
      i === (val ! "identifier")

instance Show a => Diffable (PathListItem a) where
  PathListItem n r _ === val = do
    n === (val ! "node" ! "name")
    r === (val ! "node" ! "rename")

instance Show a => Diffable (FnDecl a) where
  decl@(FnDecl as out v _) === val = do
    -- Check inputs
    as === (val ! "inputs")
  
    -- Check output
    let outTy = val ! "output" ! "variant"
    case (outTy, out) of
      ("Default", Nothing) -> pure ()
      ("Ty", Just t) -> t === (val ! "output" ! "fields" ! 0)
      _ -> diff "different output types" out outTy
  
    -- Check variadic
    let v' = val ! "variadic"
    when (Data.Aeson.Bool v /= v') $
      diff "different variadicity" decl val

instance Show a => Diffable (Arg a) where
  SelfRegion _ _ x === val =
    IdentP (ByValue Immutable) "self" Nothing x === (val ! "pat")
  SelfValue m x === val =
    IdentP (ByValue m) "self" Nothing x === (val ! "pat")
  SelfExplicit t m x === val = do
    IdentP (ByValue m) "self" Nothing x === (val ! "pat")
    t === (val ! "ty")
  Arg p t _ === val = do
    let p' = fromMaybe (IdentP (ByValue Immutable) invalidIdent Nothing undefined) p
    p' === (val ! "pat")
    t === (val ! "ty")

instance Diffable Unsafety where
  Unsafe === val | val ! "variant" == "Unsafe" = pure ()
  Normal === "Normal" = pure ()
  Normal === "Default" = pure ()
  unsfty === val = diff "different safety" unsfty val

instance Diffable Constness where
  c === val = case (val ! "node", c) of
                ("Const", Const) -> pure ()
                ("NotConst", NotConst) -> pure ()
                _ -> diff "different constness" c val

instance Diffable Abi where
  Cdecl             === "Cdecl"             = pure ()
  Stdcall           === "Stdcall"           = pure ()
  Fastcall          === "Fastcall"          = pure ()
  Vectorcall        === "Vectorcall"        = pure ()
  Aapcs             === "Aapcs"             = pure ()
  Win64             === "Win64"             = pure ()
  SysV64            === "SysV64"            = pure ()
  PtxKernel         === "PtxKernel"         = pure ()
  Msp430Interrupt   === "Msp430Interrupt"   = pure ()
  X86Interrupt      === "X86Interrupt"      = pure ()
  Rust              === "Rust"              = pure ()
  C                 === "C"                 = pure ()
  System            === "System"            = pure ()
  RustIntrinsic     === "RustIntrinsic"     = pure ()
  RustCall          === "RustCall"          = pure ()
  PlatformIntrinsic === "PlatformIntrinsic" = pure ()
  Unadjusted        === "Unadjusted"        = pure ()
  a                 === val                 = diff "different ABI" a val

instance Show a => Diffable (Generics a) where
  Generics lts tys whr _ === val = do
    lts === (val ! "lifetimes")
    tys === (val ! "ty_params")
    whr === (val ! "where_clause")


instance Show a => Diffable (LifetimeDef a) where
  LifetimeDef as l bd _ === val = do
    NullList as === (val ! "attrs" ! "_field0")
    l === (val ! "lifetime")
    bd === (val ! "bounds")

instance Show a => Diffable (TyParam a) where
  TyParam as i bd d _ === val = do
    NullList as === (val ! "attrs" ! "_field0")
    i === (val ! "ident")
    bd === (val ! "bounds")
    d === (val ! "default")

instance Show a => Diffable (WhereClause a) where
  WhereClause preds _ === val = preds === (val ! "predicates")

instance Show a => Diffable (WherePredicate a) where
  w === val =
    case (val ! "variant", w) of
      ("BoundPredicate", BoundPredicate ls t bds _) -> do
        ls === (val ! "fields" ! 0 ! "bound_lifetimes")
        t === (val ! "fields" ! 0 ! "bounded_ty")
        bds === (val ! "fields" ! 0 ! "bounds")
      ("RegionPredicate", RegionPredicate l bs _) -> do
        l === (val ! "fields" ! 0 ! "lifetime")
        bs === (val ! "fields" ! 0 ! "bounds")
      ("EqPredicate", EqPredicate l r _) -> do
        l === (val ! "fields" ! 0 ! "lhs_ty")
        r === (val ! "fields" ! 0 ! "rhs_ty")
      _ -> diff "different where predicate" w val

instance Show a => Diffable (Block a) where
  Block ss ru _ === val = do
    ss === (val ! "stmts")
    ru === (val ! "rules")

instance Show a => Diffable (Stmt a) where
  stmt === val = do
    let n' = val ! "node"
    case (n' ! "variant", stmt) of
      ("Local", Local p t i as _) -> do
        p === (n' ! "fields" ! 0 ! "pat")
        t === (n' ! "fields" ! 0 ! "ty")
        i === (n' ! "fields" ! 0 ! "init")
        NullList as === (n' ! "fields" ! 0 ! "attrs" ! "_field0")
      ("Expr", NoSemi e _)   -> e === (n' ! "fields" ! 0) 
      ("Semi", Semi e _)     -> e === (n' ! "fields" ! 0)
      ("Item", ItemStmt i _) -> i === (n' ! "fields" ! 0)
      ("Mac", MacStmt m s as _) -> do
        m === (n' ! "fields" ! 0 ! 0)
        s === (n' ! "fields" ! 0 ! 1)
        NullList as === (n' ! "fields" ! 0 ! 2 ! "_field0")
      _ -> diff "different statements" stmt val

instance Diffable MacStmtStyle where
  SemicolonMac === "Semicolon" = pure ()
  BracesMac    === "Braces"    = pure ()
  sty          === val         = diff "different styles" sty val

instance Show a => Diffable (Visibility a) where
  PublicV === "Public" = pure ()
  CrateV  === "Crate" = pure ()
  RestrictedV p === val = do
    mkIdent "Restricted" === (val ! "variant")
    p === (val ! "fields" ! 0) 
  InheritedV === "Inherited" = pure ()
  v === val = diff "different visibilities" v val

instance Show a => Diffable (Attribute a) where
  a@(Attribute sty meta sug _) === val = do
    case (val ! "style", sty) of
      ("Inner", Inner) -> pure ()
      ("Outer", Outer) -> pure ()
      _ -> diff "attribute style is different" a val

    sug === (val ! "is_sugared_doc")
    if sug
      then case (sty, meta) of
             (Inner, NameValue "doc" (Str str Cooked Unsuffixed x) y) -> NameValue "doc" (Str ("/*!" <> str <> "*/") Cooked Unsuffixed x) y === (val ! "value")
             (Outer, NameValue "doc" (Str str Cooked Unsuffixed x) y) -> NameValue "doc" (Str ("///" <> str)         Cooked Unsuffixed x) y === (val ! "value")
             _ -> diff "invalid doc comment" a val
      else meta === (val ! "value")

instance Show a => Diffable (MetaItem a) where
  meta === val = do
    -- Check that the names match
    case meta of
      Word i _        -> i === (val ! "name")
      List i _ _      -> i === (val ! "name")
      NameValue i _ _ -> i === (val ! "name")
  
    case (val ! "node", meta)  of
      ("Word", Word{}) -> pure()
      (val',          _) ->
        case (val' ! "variant", meta) of
          ("NameValue", NameValue _ lit _) -> lit === (val' ! "fields" ! 0) 
          ("List",      List _ args _) -> args === (val' ! "fields" ! 0)
          _ -> diff "metaitem is different" meta val
    
instance Show a => Diffable (NestedMetaItem a) where
  n === val =  do
    let val' = val ! "node"
    case (val' ! "variant", n) of
      ("Literal", Literal l _) -> l === (val' ! "fields" ! 0)
      ("MetaItem", MetaItem a _) -> a === (val' ! "fields" ! 0)
      _ -> diff "differing nested-metaitem" n val

instance Show a => Diffable (Pat a) where
  p' === val = do
    let val' = val ! "node"
    case (val', p') of
      ("Wild", WildP _) -> pure ()
      (Data.Aeson.Object{}, _) ->
        case (val' ! "variant", p') of
          ("Box", BoxP p _) -> p === (val' ! "fields" ! 0)
          ("Lit", LitP e _) -> e === (val' ! "fields" ! 0)
          ("Mac", MacP m _) -> m === (val' ! "fields" ! 0)
          ("Ident", IdentP bm i m _) -> do
            bm === (val' ! "fields" ! 0)
            i === (val' ! "fields" ! 1 ! "node")
            m === (val' ! "fields" ! 2)
          ("Ref", RefP p m _) -> do
            p === (val' ! "fields" ! 0)
            m === (val' ! "fields" ! 1)
          ("Struct", StructP p fp d _) -> do
            p ===  (val' ! "fields" ! 0)
            fp === (val' ! "fields" ! 1)
            when (Data.Aeson.Bool d /= (val' ! "fields" ! 2)) $ diff "differing `..'" p val
          ("TupleStruct", TupleStructP p fp mi _) -> do
            p  === (val' ! "fields" ! 0)
            fp === (val' ! "fields" ! 1)
            mi === (val' ! "fields" ! 2)
          ("Tuple", TupleP fp mi _) -> do
            fp === (val' ! "fields" ! 0)
            mi === (val' ! "fields" ! 1)
          ("Range", RangeP e1 e2 _) -> do
            e1 === (val' ! "fields" ! 0)
            e2 === (val' ! "fields" ! 1)
          ("Slice", SliceP b m a _) -> do
            b === (val' ! "fields" ! 0)
            m === (val' ! "fields" ! 1)
            a === (val' ! "fields" ! 2)
          ("Path", PathP q p _) -> do
            q === (val' ! "fields" ! 0)
            p === (val' ! "fields" ! 1)
          _ -> diff "differing patterns" p' val
      _ -> diff "differing patterns" p' val

instance Show a => Diffable (Mac a) where
  Mac p tt _ === val = do
    p === (val ! "node" ! "path")
    tt === (val ! "node" ! "tts")

instance Diffable TokenTree where
  tt === val = 
    case (val ! "variant", tt) of
      ("Token", Token _ t) -> t === (val ! "fields" ! 1)
      ("Delimited", Delimited _ d _ tt' _) -> do
        d === (val ! "fields" ! 1 ! "delim")
        tt' === (val ! "fields" ! 1 ! "tts")
      _ -> diff "different token trees" tt val

instance Diffable Delim where
  Paren   === "Paren"   = pure ()
  Bracket === "Bracket" = pure ()
  Brace   === "Brace"   = pure ()
  del     === val      = diff "different delimiters" del val

instance Diffable Token where
  Comma === "Comma" = pure ()
  Dot === "Dot" = pure ()
  Equal === "Eq" = pure ()
  NotEqual === "Ne" = pure ()
  Colon === "Colon" = pure ()
  ModSep === "ModSep" = pure ()
  Less === "Lt" = pure ()
  LessEqual === "Le" = pure ()
  Greater === "Gt" = pure ()
  GreaterEqual === "Ge" = pure ()
  Exclamation === "Not" = pure ()
  Dollar === "Dollar" = pure ()
  FatArrow === "FatArrow" = pure ()
  Semicolon === "Semi" = pure ()
  Tilde === "Tilde" = pure ()
  EqualEqual === "EqEq" = pure ()
  Underscore === "Underscore" = pure ()
  At === "At" = pure ()
  Pound === "Pound" = pure ()
  PipePipe === "OrOr" = pure ()
  DotDot === "DotDot" = pure ()
  DotDotDot === "DotDotDot" = pure ()
  RArrow === "RArrow" = pure ()
  LArrow === "LArrow" = pure ()
  Question === "Question" = pure ()
  AmpersandAmpersand === "AndAnd" = pure ()
  t === val@Object{} =
    case (val ! "variant", t) of
      ("Ident", IdentTok i) -> i === (val ! "fields" ! 0)
      ("Lifetime", LifetimeTok l) -> ("'" <> l) === (val ! "fields" ! 0)
      ("DocComment", Doc s InnerDoc) -> ("/*!" <> mkIdent s <> "*/") === (val ! "fields" ! 0)
      ("DocComment", Doc s OuterDoc) -> ("///" <> mkIdent s) === (val ! "fields" ! 0)
      ("Literal", LiteralTok l s) -> do
        l === (val ! "fields" ! 0)
        fmap mkIdent s === (val ! "fields" ! 1)
      ("BinOp", _) ->
        case (val ! "fields" ! 0, t) of
          ("Star", Star) -> pure ()
          ("Plus", Plus) -> pure ()
          ("Minus", Minus) -> pure ()
          ("Slash", Slash) -> pure ()
          ("Percent", Percent) -> pure ()
          ("And", Ampersand) -> pure ()
          ("Caret", Caret) -> pure ()
          ("Or", Pipe) -> pure ()
          ("Shr", GreaterGreater) -> pure ()
          ("Shl", LessLess) -> pure ()
          _ -> diff "differing binary operator tokens" t val
      ("BinOpEq", _) ->
        case (val ! "fields" ! 0, t) of
          ("Shr", GreaterGreaterEqual) -> pure ()
          ("Shl", LessLessEqual) -> pure ()
          ("Gt", GreaterEqual) -> pure ()
          ("Lt", LessEqual) -> pure ()
          ("Minus", MinusEqual) -> pure ()
          ("And", AmpersandEqual) -> pure ()
          ("Or", PipeEqual) -> pure ()
          ("Plus", PlusEqual) -> pure ()
          ("Star", StarEqual) -> pure ()
          ("Slash", SlashEqual) -> pure ()
          ("Caret", CaretEqual) -> pure ()
          ("Percent", PercentEqual) -> pure ()
          _ -> diff "differing binary-equal operator tokens" t val
      _ -> diff "differing tokens" t val
  t === val = diff "differing tokens" t val

instance Diffable LitTok where
  l === val =
    case (val ! "variant", l) of
      ("Byte", ByteTok s) | fromString s == (val ! "fields" ! 0) -> pure ()
      ("Char", CharTok s) | fromString s == (val ! "fields" ! 0) -> pure ()
      ("Integer", IntegerTok s) | fromString s == (val ! "fields" ! 0) -> pure ()
      ("Float", FloatTok s) | fromString s == (val ! "fields" ! 0) -> pure ()
      ("Str_", StrTok s) | fromString s == (val ! "fields" ! 0) -> pure ()
      ("StrRaw", StrRawTok s i) | fromString s == (val ! "fields" ! 0) -> i === (val ! "fields" ! 1)
      ("ByteStr", ByteStrTok s) | fromString s == (val ! "fields" ! 0) -> pure ()
      ("ByteStrRaw", ByteStrRawTok s i) | fromString s == (val ! "fields" ! 0) -> i === (val ! "fields" ! 1)
      _ -> diff "different literal token" l val

instance Show a => Diffable (FieldPat a) where
  f@(FieldPat mi p _) === val = do 
    -- Extract the identifier and whether the pattern is shorthand
    (i, s) <- case (mi,p) of
                (Nothing, IdentP _ i' Nothing _) -> pure (i', True)
                (Nothing, _) -> diff "shorthand field pattern needs to be identifier" f val
                (Just i', _) -> pure (i', False)
   
    i === (val ! "node" ! "ident")
    s === (val ! "node" ! "is_shorthand")
    p === (val ! "node" ! "pat")

instance Show a => Diffable (Field a) where
  Field i me _ === val = do 
    isNothing me === (val ! "is_shorthand")
    i === (val ! "ident" ! "node")
    me === (val ! "expr")

instance Diffable Ident where
  Ident i _ === String s | fromString i == s = pure ()
  ident'    === val = diff "identifiers are different" ident' val

instance Diffable BindingMode where
  bm === val =
    case (val ! "variant", bm) of
      ("ByValue", ByValue m) -> m === (val ! "fields" ! 0)
      ("ByRef", ByRef m) -> m === (val ! "fields" ! 0)
      _ -> diff "differing binding mode" bm val

instance Diffable Mutability where
  Mutable   === "Mutable" = pure ()
  Immutable === "Immutable" = pure ()
  m         === val = diff "differing mutability" m val

instance Show a => Diffable (Ty a) where
  t' === val = do
    let n = val ! "node"
    case (n, t') of
      ("Never", Never _) -> pure ()
      ("Infer", Infer _) -> pure ()
      (Data.Aeson.Object{}, _) ->
        case (n ! "variant", t') of
          ("Path", PathTy q p _) -> do
            q === (n ! "fields" ! 0)
            p === (n ! "fields" ! 1)
          ("Tup", TupTy t _) -> t === (n ! "fields" ! 0)
          ("Slice", Slice t _) -> t === (n ! "fields" ! 0)
          ("Array", Language.Rust.Syntax.Array t e _) -> do
            t ===   (n ! "fields" ! 0)
            e ===(n ! "fields" ! 1)
          ("Ptr", Ptr m t _) -> do
            m === (n ! "fields" ! 0 ! "mutbl")
            t === (n ! "fields" ! 0 ! "ty")
          ("Rptr", Rptr lt m t _) -> do
            lt === (n ! "fields" ! 0)
            m === (n ! "fields" ! 1 ! "mutbl")
            t === (n ! "fields" ! 1 ! "ty")
          ("BareFn", BareFn u a lts decl _) -> do
            u === (n ! "fields" ! 0 ! "unsafety")
            a === (n ! "fields" ! 0 ! "abi")
            lts === (n ! "fields" ! 0 ! "lifetimes")
            decl === (n ! "fields" ! 0 ! "decl")
          ("TraitObject", TraitObject bds _) ->
            bds === (n ! "fields" ! 0)
          ("Paren", ParenTy t _) -> t === (n ! "fields" ! 0)
          ("Typeof", Typeof e _) -> e ===(n ! "fields" ! 0)
          ("Mac", MacTy m _) -> m === (n ! "fields" ! 0)
          ("ImplTrait", ImplTrait bds _) -> bds === (n ! "fields" ! 0)
          _ -> diff "differing types" t' val
      _ -> diff "differing types" t' val


instance Show a => Diffable (TyParamBound a) where
  bd === val = case (val ! "variant", bd) of
                 ("TraitTyParamBound", TraitTyParamBound p m _) -> do
                   p === (val ! "fields" ! 0)
                   m === (val ! "fields" ! 1)
                 ("RegionTyParamBound", RegionTyParamBound l _) ->
                   l === (val ! "fields" ! 0)
                 _ -> diff "different type parameter bounds" bd val

instance Show a => Diffable (PolyTraitRef a) where
  PolyTraitRef lts tr _ === val = do
    lts === (val ! "bound_lifetimes")
    tr === (val ! "trait_ref")

instance Show a => Diffable (TraitRef a) where
  TraitRef p === val = p === (val ! "path")

instance Diffable TraitBoundModifier where
  None  === "None" = pure ()
  Maybe === "Maybe" = pure ()
  m     === val = diff "different trait boudn modifier" m val

instance Show a => Diffable (Lifetime a) where
  l@(Lifetime n _) === val
    | fromString ("'" ++ n) /= val ! "name" = diff "lifetime is different" l val
    | otherwise = pure ()

instance Show a => Diffable (QSelf a) where
  q@(QSelf t p) === val = do
    t === (val ! "ty")
    when (Number (fromIntegral p) /= (val ! "position")) $
      diff "differing position in QSelf" q val

instance Show a => Diffable (Path a) where
  Path g segs _ === val = do
    let segs' = if g then ("{{root}}", NoParameters undefined) <| segs else segs
    fmap PathPair segs' === (val ! "segments")

newtype PathPair a = PathPair (Ident, PathParameters a) deriving (Show)
instance Show a => Diffable (PathPair a) where
  PathPair (i, pp) === val = do
      --  i === (val ! "identifier")
      when (fromString (show i) /= val ! "identifier") $
        diff "path segment has different name" (i,pp) val
      pp === (val ! "parameters")

instance Show a => Diffable (PathParameters a) where
  n@(NoParameters _) === val = when (val /= Data.Aeson.Null) (diff "expected no parameters" n val) 
  p === val =
    case (val ! "variant", p) of
      ("AngleBracketed", AngleBracketed lts tys bds _) -> do
        lts === (val ! "fields" ! 0 ! "lifetimes")
        tys === (val ! "fields" ! 0 ! "types")
        map Binding bds === (val ! "fields" ! 0 ! "bindings")
      ("Parenthesized", Parenthesized is o _) -> do
        is === (val ! "fields" ! 0 ! "inputs")
        o  === (val ! "fields" ! 0 ! "output")
      _ -> diff "different path parameters" p val

newtype Binding a = Binding (Ident, Ty a) deriving (Show)
instance Show a => Diffable (Binding a) where
  Binding (i,t) === v = do
    i === (v ! "ident")
    t === (v ! "ty")

instance Show a => Diffable (Expr a) where
  ex === val =
    case (n ! "variant", ex) of
      ("Lit", Lit as l _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        l === (n ! "fields" ! 0)
      ("Tup", TupExpr as es _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        es === (n ! "fields" ! 0)
      ("Match", Match as e arms _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        arms === (n ! "fields" ! 1)
      ("Box", Box as e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
      ("InPlace", InPlace as e1 e2 _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e1 === (n ! "fields" ! 0)
        e2 === (n ! "fields" ! 1)
      ("Path", PathExpr as q p _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        q === (n ! "fields" ! 0)
        p === (n ! "fields" ! 1)
      ("Array", Vec as es _) -> do 
        NullList as === (val ! "attrs" ! "_field0")
        es === (n ! "fields" ! 0)
      ("Call", Call as f es _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        f === (n ! "fields" ! 0)
        es === (n ! "fields" ! 1)
      ("MethodCall", MethodCall as o i tys es _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        i === (n ! "fields" ! 0 ! "node")
        fromMaybe [] tys === (n ! "fields" ! 1)
        (o : es) === (n ! "fields" ! 2) 
      ("Binary", Binary as o e1 e2 _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        o === (n ! "fields" ! 0)
        e1 === (n ! "fields" ! 1) 
        e2 === (n ! "fields" ! 2) 
      ("Unary", Unary as o e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        o === (n ! "fields" ! 0)
        e === (n ! "fields" ! 1)
      ("Cast", Cast as e t _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        t === (n ! "fields" ! 1)
      ("Type", TypeAscription as e t _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        t === (n ! "fields" ! 1)
      ("Block", BlockExpr as b _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        b === (n ! "fields" ! 0)
      ("If", If as e tb ee _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        tb === (n ! "fields" ! 1)
        ee === (n ! "fields" ! 2)
      ("IfLet", IfLet as p e tb ee _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        p === (n ! "fields" ! 0)
        e === (n ! "fields" ! 1)
        tb === (n ! "fields" ! 2)
        ee === (n ! "fields" ! 3)
      ("While", While as e b l _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        b === (n ! "fields" ! 1)
        fmap Lbl l === (n ! "fields" ! 2)
      ("WhileLet", WhileLet as p e b l _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        p === (n ! "fields" ! 0)
        e === (n ! "fields" ! 1)
        b === (n ! "fields" ! 2)
        fmap Lbl l === (n ! "fields" ! 3)
      ("Continue", Continue as l _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        fmap Lbl l === (n ! "fields" ! 0)
      ("Break", Break as l e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        fmap Lbl l === (n ! "fields" ! 0)
        e === (n ! "fields" ! 1)
      ("ForLoop", ForLoop as p e b l _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        p === (n ! "fields" ! 0)
        e === (n ! "fields" ! 1)
        b === (n ! "fields" ! 2)
        fmap Lbl l === (n ! "fields" ! 3)
      ("Loop", Loop as b l _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        b === (n ! "fields" ! 0)
        fmap Lbl l === (n ! "fields" ! 1)
      ("Range", Range as l h rl _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        l === (n ! "fields" ! 0)
        h === (n ! "fields" ! 1)
        rl === (n ! "fields" ! 2) 
      ("Closure", Closure as c decl e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        c === (n ! "fields" ! 0)
        decl === (n ! "fields" ! 1)
        e === (n ! "fields" ! 2)
      ("Assign", Assign as l r _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        l === (n ! "fields" ! 0)
        r === (n ! "fields" ! 1)
      ("AssignOp", AssignOp as o l r _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        o === (n ! "fields" ! 0)
        l === (n ! "fields" ! 1)
        r === (n ! "fields" ! 2)
      ("Field", FieldAccess as e i _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        i === (n ! "fields" ! 1 ! "node")
      ("TupField", TupField as e i _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
        i === (n ! "fields" ! 1 ! "node")
      ("Index", Language.Rust.Syntax.Index as e1 e2 _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e1 === (n ! "fields" ! 0)
        e2 === (n ! "fields" ! 1)
      ("AddrOf", AddrOf as m e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        m === (n ! "fields" ! 0)
        e === (n ! "fields" ! 1)
      ("Ret", Ret as e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0)
      ("Mac", MacExpr as m _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        m === (n ! "fields" ! 0)
      ("Struct", Struct as p f e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        p === (n ! "fields" ! 0)
        f === (n ! "fields" ! 1)
        e === (n ! "fields" ! 2)
      ("Repeat", Repeat as e1 e2 _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e1 === (n ! "fields" ! 0)
        e2 === (n ! "fields" ! 1)
      ("Paren", ParenExpr as e' _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e' === (n ! "fields" ! 0)
      ("Try", Try as e _) -> do
        NullList as === (val ! "attrs" ! "_field0")
        e === (n ! "fields" ! 0) 
      _ -> diff "differing expressions:" ex val
    where
    n = val ! "node"

newtype Lbl a = Lbl (Lifetime a) deriving (Show)
instance Show a => Diffable (Lbl a) where
  Lbl l@(Lifetime n _) === val = when (String (fromString ("'" ++ n)) /= val ! "node") $
                                   diff "labels are different" l val

instance Diffable CaptureBy where
  Value === "Value" = pure ()
  Ref   === "Ref" = pure ()
  c     === val = diff "different capture by" c val


instance Diffable RangeLimits where
  HalfOpen === "HalfOpen" = pure ()
  Closed   === "Closed" = pure ()
  rl       === val = diff "different range limits" rl val

instance Diffable BinOp where
  b === val =
    case (val ! "node", b) of
      ("Add",    AddOp   ) -> pure () 
      ("Sub",    SubOp   ) -> pure () 
      ("Mul",    MulOp   ) -> pure () 
      ("Div",    DivOp   ) -> pure () 
      ("Rem",    RemOp   ) -> pure () 
      ("And",    AndOp   ) -> pure () 
      ("Or",     OrOp    ) -> pure () 
      ("BitXor", BitXorOp) -> pure () 
      ("BitAnd", BitAndOp) -> pure () 
      ("BitOr",  BitOrOp ) -> pure () 
      ("Shl",    ShlOp   ) -> pure () 
      ("Shr",    ShrOp   ) -> pure () 
      ("Eq",     EqOp    ) -> pure () 
      ("Lt",     LtOp    ) -> pure () 
      ("Le",     LeOp    ) -> pure () 
      ("Ne",     NeOp    ) -> pure () 
      ("Ge",     GeOp    ) -> pure () 
      ("Gt",     GtOp    ) -> pure () 
      _ -> diff "different binary operation" b val

instance Diffable UnOp where
  Deref === "Deref" = pure ()
  Not   === "Not"   = pure ()
  Neg   === "Neg"   = pure ()
  u     === val     = diff "different unary operator" u val

instance Show a => Diffable (Arm a) where
  Arm as ps g b _ === val = do
    as === (val ! "attrs")
    ps === (val ! "pats")
    g  === (val ! "guard")
    b  === (val ! "body")

instance Show a => Diffable (Lit a) where
  l === val = do
    let n = val ! "node"
    case (n ! "variant", l) of
      ("Int", Int _ i suf _) -> do
        when (Number (fromInteger i) /= n ! "fields" ! 0) $
          diff "int literal has two different values" l val
        suf === (n ! "fields" ! 1)
      ("Float", Float f suf _) -> do
        let String j = n ! "fields" ! 0
        when (f /= read (T.unpack j)) $
          diff "float literal has two different values" l val
        suf === (n ! "fields" ! 1)
      ("Str", Str s sty Unsuffixed _) -> do
        when (String (fromString s) /= n ! "fields" ! 0) $
          diff "string literal has two different values" l val
        sty === (n ! "fields" ! 1)
      ("Char", Char c Unsuffixed _) ->
        when (String (fromString [c]) /= n ! "fields" ! 0) $
          diff "character literal has two different values" l val
      ("Byte", Byte b Unsuffixed _) ->
        b === (n ! "fields" ! 0)
      ("ByteStr", ByteStr s _ Unsuffixed _) ->
        s === (n ! "fields" ! 0)
      ("Bool", Language.Rust.Syntax.Bool b Unsuffixed _) ->
        when (Data.Aeson.Bool b /= n ! "fields" ! 0) $
          diff "boolean literal has two different values" l val
      _ -> diff "different literals" l val

instance Diffable StrStyle where
  Cooked === "Cooked" = pure ()
  (Raw n) === val | val ! "variant" == "Raw" = n === (val ! "fields" ! 0)
  sty === val = diff "different string style" sty val

instance Diffable Suffix where
  Unsuffixed === "Unsuffixed" = pure ()
  F32 === "F32" = pure ()
  F64 === "F64" = pure ()
  Is === val   | val ! "fields" == Data.Aeson.Array ["Is"]   = pure () 
  I8 === val   | val ! "fields" == Data.Aeson.Array ["I8"]   = pure () 
  I16 === val  | val ! "fields" == Data.Aeson.Array ["I16"]  = pure () 
  I32 === val  | val ! "fields" == Data.Aeson.Array ["I32"]  = pure () 
  I64 === val  | val ! "fields" == Data.Aeson.Array ["I64"]  = pure () 
  I128 === val | val ! "fields" == Data.Aeson.Array ["I128"] = pure () 
  Us === val   | val ! "fields" == Data.Aeson.Array ["Us"]   = pure () 
  U8 === val   | val ! "fields" == Data.Aeson.Array ["U8"]   = pure () 
  U16 === val  | val ! "fields" == Data.Aeson.Array ["U16"]  = pure () 
  U32 === val  | val ! "fields" == Data.Aeson.Array ["U32"]  = pure () 
  U64 === val  | val ! "fields" == Data.Aeson.Array ["U64"]  = pure () 
  U128 === val | val ! "fields" == Data.Aeson.Array ["U128"] = pure () 
  u === val = diff "different suffix" u val

