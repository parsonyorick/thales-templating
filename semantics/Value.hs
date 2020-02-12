{-# LANGUAGE StrictData #-}
module Value where

import qualified Data.HashMap.Strict as Map
import Data.Scientific
import Data.Vector as Vec
import Text.Show

import BaseMonad
import Syntax
import Verbatim

data Value where
  Number :: Scientific -> Value
  String :: Text -> Value
  Verbatim :: Verbatim -> Value
  Boolean :: Bool -> Value
  Array :: (Vector Value) -> Value
  Record :: HashMap Name Value -> Value
  Function :: ValueType a -> (a -> M Value) -> Value

instance Eq Value where
  (Number a1) == (Number a2) =
    a1 == a2
  (String a1) == (String a2) =
    a1 == a2
  (Verbatim a1) == (Verbatim a2) =
    a1 == a2
  (Array a1) == (Array a2) =
    a1 == a2
  (Record a1) == (Record a2) =
    a1 == a2
  (Function {}) == (Function {}) =
    error "Cannot equate functions!"
  _ == _ =
    False

data ValueType t where
  NumberT :: ValueType Scientific
  StringT :: ValueType Text
  BooleanT :: ValueType Bool
  ArrayT :: ValueType (Vector Value)
  RecordT :: ValueType (HashMap Name Value)
  FunctionT :: ValueType a -> ValueType (a -> M Value)

data SomeValueType where
  SomeValueType :: ValueType t -> SomeValueType

instance Eq SomeValueType where
  (SomeValueType NumberT) == (SomeValueType NumberT) = True
  (SomeValueType StringT) == (SomeValueType StringT) = True
  (SomeValueType BooleanT) == (SomeValueType BooleanT) = True
  (SomeValueType ArrayT) == (SomeValueType ArrayT) = True
  (SomeValueType RecordT) == (SomeValueType RecordT) = True
  (SomeValueType (FunctionT t1)) == (SomeValueType (FunctionT t2)) =
    SomeValueType t1 == SomeValueType t2
  _ == _ = False

instance Show SomeValueType where
  showsPrec _prec (SomeValueType vt) = case vt of
    NumberT -> s "number"
    StringT -> s "text"
    BooleanT -> s "bool"
    ArrayT -> s "array"
    RecordT -> s "record"
    FunctionT _t -> s "function"
    where s = (Prelude.++)

instance Show Value where
  showsPrec prec = \case
    Number  s -> showsPrec prec s
    String  t -> showsPrec prec t
    Boolean b -> showsPrec prec b
    Record  h ->
        ('{' :)
      . Map.foldrWithKey
        (\k v s -> showsPrec prec k . (':':) . showsPrec prec v . s) id h
      . ('}' :)
    Array   a -> showList (Vec.toList a)
    Verbatim _v -> ("..." <>)
    Function _ _ -> ("<function>" <>)