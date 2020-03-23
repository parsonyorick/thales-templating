{-# OPTIONS_GHC -Wno-missing-signatures #-}
module Main (main) where

import qualified Control.Applicative.Combinators.NonEmpty as NE
import Development.Shake
import qualified Data.Text as Text
import Options.Applicative
import Options.Applicative.Help.Pretty
import System.Directory
import System.FilePath
import System.IO hiding (print)

import qualified Bindings
import DependencyMonad hiding (listDirectory)
import qualified NonEmptyText
import qualified Output
import Parse
import Syntax
import Value

main = do
  options@Options{..} <- customExecParser cliPrefs cli
  when (optVerbosity >= Verbose) $
    print options
  run options $ do
    want optTargets
    (`elem` optTargets) ?> \targetPath -> do
      let templatePath = targetPath <.> templateExtension
      val <- lookupField (TemplateFile Bindings.empty) templatePath "body"
      case val of
        Just (Output outp) ->
          liftIO $ withBinaryFile targetPath WriteMode $ \hdl -> do
            hSetBuffering hdl (BlockBuffering Nothing)
            Output.write hdl (Output.fromStorable outp)
        _ ->
          error "Oh no!!!"

cli =
  info (optionsParser <**> helper) $
    fullDesc <>
    progDesc cliDescription <>
    headerDoc (Just cliHeader) <>
    footer cliFooter

cliPrefs =
  prefs $
    showHelpOnEmpty <> columns 72

cliHeader =
  vsep
    [ "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    , "––– The Thales templating system –––"
    , "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" ]
  `flatAlt`
  "~~~ The Thales templating system ~~~"

cliDescription =
  "Thales takes template files, containing text of whatever shape you like interspersed " <>
  "with specially delimited template directives, and interprets the directives, " <>
  "substituting their results back into the template to produce the target file. " <>
  "Template directives allow for inclusion of values from YAML files, Markdown files, " <>
  "and from other templates. Thales tracks the dependencies of each template, so that if " <>
  "a target is requested which has been built before and whose dependencies have not " <>
  "since changed, it will not be rebuilt."

cliFooter =
  "For further documentation, see the README on GitHub at https://github.com/parsonyorick/thales-templating#readme."

optionsParser =
  Options
    <$> targetArguments
    <*> rebuildOption
    <*> delimitersOption
    <*> verbosityOption
    <*> timingsOption
  where
    targetArguments =
      some $ strArgument $
        metavar "TARGETS" <>
        help ("Files to be built from the corresponding templates. The template for a " <>
             "given FILE is assumed to be called \"FILE.template\".") <>
        completer (listIOCompleter getPossibleTargets)
    rebuildOption =
      (Just . SomeThings <$> NE.some (strOption $
        metavar "PATTERN" <>
        long "rebuild" <>
        short 'r' <>
        help ("Rebuild targets matching this glob pattern, regardless of whether their " <>
              "dependencies have changed. This option may be given multiple times."))) <|>
      (flag Nothing (Just Everything) (
        long "rebuild-all" <> short 'R' <>
        help "Rebuild all targets, regardless of whether dependencies have changed."))
    delimitersOption =
      option (eitherReader parseDelimiters) $
        long "delimiters" <>
        short 'd' <>
        metavar "BEGIN,END" <>
        value defaultDelimiters <>
        showDefaultWith showDelimiters <>
        help "A pair of strings, separated by a comma, that delimit template directives."
    verbosityOption =
      flag' Silent (long "silent" <> short 's' <> help "Print no messages.") <|>
      flag' Warn (long "warn" <> short 'w' <> help "Print errors and warnings only. (This is the default.)") <|>
      flag' Info (long "info" <> short 'i' <> help "Print errors, warnings, and possibly a handful of discretionary messages.") <|>
      flag' Verbose (long "verbose" <> short 'v' <> help "Print a message for everything that happens, plus errors and warnings.") <|>
      flag' Diagnostic (long "diagnostic" <> help "Print all manner of debugging info, plus everything that --verbose prints.") <|>
      pure Warn
    timingsOption =
      switch $
        long "timings" <>
        short 't' <>
        hidden <>
        help "Print some coarse-grained timing information that Shake calculates."

getPossibleTargets :: IO [String]
getPossibleTargets =
  map dropExtension . filter (templateExtension `isExtensionOf`) <$> listDirectory "."

templateExtension = "template"

parseDelimiters :: String -> Either String Delimiters
parseDelimiters s = maybe (Left errMsg) Right $ do
  let (before, comma_after) = break (== delimitersSeparator) s
  after <- viaNonEmpty tail comma_after
  before_ne <- nonEmpty before
  after_ne <- nonEmpty after
  return $
    Delimiters
      (NonEmptyText.fromNonEmptyString before_ne)
      (NonEmptyText.fromNonEmptyString after_ne)
 where
  errMsg =
    "Argument is not of the form \"<string>,<string>\""

showDelimiters :: Delimiters -> String
showDelimiters Delimiters{..} =
  Text.unpack (NonEmptyText.toText begin) <>
  [delimitersSeparator] <>
  Text.unpack (NonEmptyText.toText end)

delimitersSeparator = ','
