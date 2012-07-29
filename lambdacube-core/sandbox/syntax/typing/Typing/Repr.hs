module Typing.Repr where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Set.Unicode

import Control.Monad.Writer
import Text.PrettyPrint.Leijen

type Id = String

type Tv = Id
type TyCon = Id

data Ty = TyCon TyCon
        | TyVar Tv
        | TyApp Ty Ty
        | TyFun
        deriving Show

instance Pretty Ty where
    pretty = go False
      where
        go :: Bool -> Ty -> Doc
        go prec ty = case ty of
            -- XXX remove this
            TyApp (TyCon "[]") t -> brackets (go False t)
            TyCon con -> text con
            TyVar α -> text α
            TyApp (TyApp TyFun t) u -> paren $ go True t <+> text "->" <+> go False u
            TyApp t u -> paren $ go False t <+> go True u
            TyFun -> text "(->)"
          where
            paren = if prec then parens else id

tyFunResult :: Ty -> Ty
tyFunResult (TyApp (TyApp TyFun _) t) = tyFunResult t
tyFunResult t = t

tvs :: Ty -> Set Tv
tvs = execWriter . go
  where
    collect = tell . Set.singleton

    go ty = case ty of
        TyVar t -> collect t
        TyApp t u -> go t >> go u
        _ -> return ()

occurs :: Tv -> Ty -> Bool
occurs x ty = x ∈ tvs ty

infixr ~>
(~>) :: Ty -> Ty -> Ty
t ~> u = TyApp (TyApp TyFun t) u

type Var = Id

type Con = Id

data Def = DefVar Var Expr
         | DefFun Var [Match]

data Match = Match [Pat] Expr

data Pat = PVar Var
         | PCon Con [Pat]
         | PWildcard

data Expr = EVar Var
          | ECon Con
          | ELam Pat Expr
          | EApp Expr Expr
          | ELet Defs Expr

data Defs = Defs [[Def]] -- NOTE: this assumes the defs are already grouped into SCC's