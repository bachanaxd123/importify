{-# LANGUAGE TemplateHaskell #-}

-- | Tests for @importify file@ command.

module Test.File
       ( spec
       ) where

import           Universum

import           Data.Algorithm.Diff (Diff (Both), getDiff)
import           Data.List           (sort)
import           Path                (Dir, File, Path, Rel, dirname, fileExtension,
                                      filename, fromRelDir, fromRelFile, mkRelFile,
                                      (-<.>), (</>))
import           Path.IO             (listDir)
import           System.Wlog         (Severity)

import           Test.Hspec          (Spec, describe, it, runIO, shouldBe, xit)

import           Importify.Main      (importifyFileContent)
import           Importify.Path      (testDataPath)

spec :: Spec
spec = do
    (testFolders, _) <- runIO $ listDir testDataPath
    describe "file:unused" $
        mapM_ (makeTestGroup . (testDataPath </> ) . dirname) testFolders

makeTestGroup :: Path Rel Dir -> Spec
makeTestGroup testCasesPath = do
    (_, testDirPaths) <- runIO $ listDir testCasesPath
    let testHsOnly     = sort
                       $ filter ((== ".hs") . fileExtension)
                       $ map filename testDirPaths

    describe ("subfolder: " ++ fromRelDir testCasesPath) $
        mapM_ (makeTest testCasesPath) testHsOnly

makeTest :: Path Rel Dir -> Path Rel File -> Spec
makeTest testDirPath testCasePath = do
    diff <- runIO $ loadTestDataDiff testDirPath testCasePath
    let testType = if elem testCasePath pendingTests then xit else it
    testType (fromRelFile testCasePath) $ diff `shouldBe` []

pendingTests :: [Path Rel File]
pendingTests = [$(mkRelFile "01-ImportBothUsedQualified.hs") -- Importify can't modify source yet
               ]

loadTestDataDiff :: Path Rel Dir -> Path Rel File -> IO [Diff Text]
loadTestDataDiff testDirPath testCasePath = do
    let fullPathToTest = testDirPath </> testCasePath
    goldenExamplePath <- fullPathToTest -<.> ".golden"

    goldenExampleSrc     <- readFile (fromRelFile goldenExamplePath)
    Right importifiedSrc <- importifyFileContent fullPathToTest

    return $ filter isDivergent $ getDiff (lines importifiedSrc)
                                          (lines goldenExampleSrc)

isDivergent :: Diff Text -> Bool
isDivergent (Both _ _) = False
isDivergent _          = True