from __future__ import annotations

import re
import plistlib
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class IOSGameDataPickerContractTests(unittest.TestCase):
    def test_picker_does_not_filter_disc_images_by_dynamic_uti(self) -> None:
        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        match = re.search(
            r"NSArray<UTType \*> \*KartPadGameDataContentTypes\(\) \{(.*?)\n\}",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        body = match.group(1)

        self.assertIn(
            "return @[UTTypeItem, UTTypeData, UTTypeDiskImage, UTTypeFolder];",
            body,
        )
        self.assertNotIn("typeWithFilenameExtension", body)
        self.assertEqual(
            source.count(
                "initForOpeningContentTypes:KartPadGameDataContentTypes()"
            ),
            2,
        )
        # Both entry points must allow directories to be opened, and must not
        # delete a provider's original after copying into KartPad's private store.
        self.assertEqual(source.count(
            "initForOpeningContentTypes:KartPadGameDataContentTypes() asCopy:NO"), 2)
        self.assertIn("initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO", source)
        self.assertNotIn("self.choosingGameDataCopy = YES", source)
        self.assertIn("[self importExtractedGameDataFromURL:url deleteAfterwards:NO]", source)
        self.assertNotIn("[self importExtractedGameDataFromURL:url deleteAfterwards:YES]", source)
        self.assertIn("choosingGameDataCopy", source)
        self.assertIn("deleteAfterwards:deleteAfterwards", source)

    def test_provider_read_is_coordinated_before_releasing_access(self) -> None:
        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        body = source.split("NSError *KartPadPerformGameDataImport(", 1)[1]
        body = body.split("\n}\n", 1)[0]
        self.assertIn("coordinateReadingItemAtURL:url", body)
        self.assertIn("extractImageAtPath:readingURL.path", body)
        self.assertIn("KartPadResolvedExtractedRoot(readingURL)", body)
        self.assertLess(body.index("copyItemAtPath:sourceRoot"),
                        body.index("stopAccessingSecurityScopedResource"))
        self.assertIn("workError = coordinationError", body)

    def test_documents_scan_checks_disc_extension_before_directory_metadata(self) -> None:
        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        match = re.search(
            r"NSArray<NSURL \*> \*KartPadGameDataRootsInDocuments\(NSError \*\*error\)"
            r" \{(.*?)\n\}",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        body = match.group(1)
        self.assertLess(
            body.index("KartPadURLIsSupportedDiscImage(entry)"),
            body.index("getResourceValue:&directory"),
        )
        self.assertNotIn("!directory.boolValue", body)
        self.assertEqual(source.count("KartPadGameDataRootsInDocuments(&error)"), 1)

    def test_open_in_place_and_files_folder_contracts_are_declared(self) -> None:
        for name in ("Info.plist", "RuntimeInfo.plist"):
            with (REPO / "apple/ios" / name).open("rb") as handle:
                info = plistlib.load(handle)
            self.assertIs(info.get("UIFileSharingEnabled"), True, name)
            self.assertIs(
                info.get("LSSupportsOpeningDocumentsInPlace"), True, name
            )

        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn("KartPadDocumentsRoot(&documentsError)", source)

    def test_empty_installation_folder_scan_falls_back_directly_to_picker(self) -> None:
        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn("KartPadDocumentsFolderScanDetail", source)
        self.assertIn("NSBundle.mainBundle.bundleIdentifier", source)
        self.assertIn("If a signer changes the bundle identifier", source)
        self.assertEqual(
            source.count('actionWithTitle:@"Import from Extracted Folder…"'),
            2,
        )
        self.assertIn("[self presentGameDataPicker];", source)
        self.assertIn("[self presentGameDataFolderPicker];", source)
        self.assertIn("gameOverlayRequestsGameDataFolderImport:weakSelf", source)
        self.assertEqual(
            source.count('NSLog(@"[KartPad] %@", KartPadDocumentsFolderScanDetail(error));'),
            1,
        )
        self.assertEqual(source.count("KartPadGameDataRootsInDocuments(&error)"), 1)


if __name__ == "__main__":
    unittest.main()
