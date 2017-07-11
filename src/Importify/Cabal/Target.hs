{-# LANGUAGE TupleSections #-}

-- | Functions to retrieve and store mapping from modules to their
-- targets and extensions.

module Importify.Cabal.Target
       ( ExtensionsMap
       , TargetsMap
       , MapBundle
       , getExtensionMaps
       ) where

import           Universum                       hiding (fromString)

import qualified Data.HashMap.Strict             as HM
import           Distribution.ModuleName         (ModuleName)
import           Distribution.PackageDescription (Benchmark (benchmarkBuildInfo),
                                                  BuildInfo (..), CondTree,
                                                  Executable (buildInfo),
                                                  GenericPackageDescription (..),
                                                  Library (..), TestSuite (testBuildInfo),
                                                  benchmarkModules, condTreeData,
                                                  exeModules, libModules, testModules)
import           Distribution.Text               (display)
import           Language.Haskell.Extension      (Extension (..))

import           Importify.Cabal.Extension       (showExt)


type    TargetsMap = HashMap String String
type ExtensionsMap = HashMap String [String]
type MapBundle     = (TargetsMap, ExtensionsMap)

data TargetId = LibraryId
              | ExecutableId String
              | TestSuiteId  String
              | BenchmarkId  String

cabalTargetId :: TargetId -> String
cabalTargetId LibraryId               = "library"
cabalTargetId (ExecutableId exeName)  = "executable " ++ exeName
cabalTargetId (TestSuiteId testName)  = "test-suite " ++ testName
cabalTargetId (BenchmarkId benchName) = "benchmark "  ++ benchName

getExtensionMaps :: GenericPackageDescription -> MapBundle
getExtensionMaps GenericPackageDescription{..} =
    ( HM.unions $ libTM : exeTMs ++ testTMs ++ benchTMs
    , HM.unions $ libEM : exeEMs ++ testEMs ++ benchEMs
    )
  where
    (libTM, libEM) =
        maybe mempty (collectLibraryMaps . condTreeData) condLibrary

    (exeTMs, exeEMs) =
        collectTargetsListMaps condExecutables
                               ExecutableId
                               (collectTargetMaps exeModules buildInfo)

    (testTMs, testEMs) =
        collectTargetsListMaps condTestSuites
                               TestSuiteId
                               (collectTargetMaps testModules testBuildInfo)

    (benchTMs, benchEMs) =
        collectTargetsListMaps condBenchmarks
                               BenchmarkId
                               (collectTargetMaps benchmarkModules benchmarkBuildInfo)

collectLibraryMaps :: Library -> MapBundle
collectLibraryMaps = collectTargetMaps libModules libBuildInfo LibraryId

collectTargetsListMaps :: [(String, CondTree v c target)]
                       -> (String -> TargetId)
                       -> (TargetId -> target -> MapBundle)
                       -> ([TargetsMap], [ExtensionsMap])
collectTargetsListMaps treeList idConstructor mapBundler = unzip $ do
    (name, condTree) <- treeList
    pure $ mapBundler (idConstructor name) $ condTreeData condTree

collectTargetMaps :: (target -> [ModuleName])
                  -> (target -> BuildInfo)
                  -> TargetId
                  -> target
                  -> MapBundle
collectTargetMaps modulesExtractor buildInfoExtractor id target =
    collectModuleMaps (cabalTargetId id)
                      (map display $ modulesExtractor target)
                      (defaultExtensions $ buildInfoExtractor target)

collectModuleMaps :: String -> [String] -> [Extension] -> MapBundle
collectModuleMaps targetName modules extensions =
    ( HM.fromList $ map (, targetName) modules
    , one (targetName, map showExt extensions)
    )
