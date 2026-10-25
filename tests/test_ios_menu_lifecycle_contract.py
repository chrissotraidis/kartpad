from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class IOSMenuLifecycleContractTests(unittest.TestCase):
    def test_menu_uses_one_capsule_configuration_for_all_states(self) -> None:
        source = (REPO / "apple/ios/KartPadMenuButton.h").read_text()
        self.assertIn("UIButtonConfigurationCornerStyleCapsule", source)
        self.assertIn("configuration.image = image;", source)
        self.assertIn("button.automaticallyUpdatesConfiguration = NO;", source)
        self.assertIn("background.strokeWidth = 1.0;", source)

    def test_shell_and_runtime_apply_the_menu_configuration(self) -> None:
        shell = (REPO / "apple/ios/KartPadShellViewController.mm").read_text()
        runtime = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn("KartPadConfigureMenuButton(KartPadFindMenuButton(_overlay));", shell)
        self.assertIn("KartPadConfigureMenuButton(menuButton);", runtime)

    def test_kartpad_menu_has_bounded_top_level_groups(self) -> None:
        runtime = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn('menuWithTitle:@"Controls"', runtime)
        self.assertIn('identifier:@"dev.kartpad.controls"', runtime)
        self.assertIn('menuWithTitle:@"Display"', runtime)
        self.assertIn('identifier:@"dev.kartpad.display"', runtime)

        controls = runtime.index('menuWithTitle:@"Controls"')
        display = runtime.index('menuWithTitle:@"Display"')
        self.assertLess(runtime.index("[controlItems addObject:controllerMapping]"), controls)
        self.assertLess(runtime.index("[controlItems addObject:touchControlSettings]"), controls)
        self.assertLess(runtime.index("[controlItems addObject:motionSteering]"), controls)
        self.assertLess(runtime.index("[displayItems addObject:aspectRatio]"), display)
        self.assertLess(runtime.index("[displayItems addObject:renderResolution]"), display)
        # Show FPS Counter lives in Display, first, as on Android (docs/SETTINGS.md).
        self.assertLess(runtime.index("[displayItems addObject:fpsCounter]"),
                        runtime.index("[displayItems addObject:aspectRatio]"))

        root_start = runtime.index(
            "NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];"
        )
        root_end = runtime.index('menuButton.menu = [UIMenu menuWithTitle:@"KartPad"')
        root = runtime[root_start:root_end]
        expected_order = [
            "[children addObject:multiplayer]",
            "[children addObject:controls]",
            "[children addObject:display]",
            "[children addObject:gameData]",
            "[children addObject:reportProblem]",
        ]
        offsets = [root.index(value) for value in expected_order]
        self.assertEqual(offsets, sorted(offsets))
        self.assertNotIn("[children addObject:fpsCounter]", root)

    def test_inherited_refresh_cannot_restore_the_sunpad_menu(self) -> None:
        runtime = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        refresh = runtime.split("- (void)refreshMenuButton {", 1)[1].split(
            "- (void)layoutSubviews {", 1
        )[0]
        self.assertIn("[super refreshMenuButton];", refresh)
        self.assertIn("[self setNeedsLayout];", refresh)
        self.assertIn("[self layoutIfNeeded];", refresh)
        self.assertIn('hasPrefix:@"Experimental Performance Mode"', runtime)
        self.assertIn('hasPrefix:@"Experimental 60 FPS"', runtime)
        self.assertIn('menuButton.menu = [UIMenu menuWithTitle:@"KartPad"', runtime)

    def test_foreground_reasserts_overlay_attachment_and_z_order(self) -> None:
        shell = (REPO / "apple/ios/KartPadShellViewController.mm").read_text()
        runtime = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn("_overlay.superview != self.view", shell)
        self.assertGreaterEqual(shell.count("bringSubviewToFront"), 3)
        self.assertIn("- (void)reattachOverlayIfNeeded", runtime)
        self.assertIn("[self reattachOverlayIfNeeded];", runtime)
        self.assertIn("[weakSelf reattachOverlayIfNeeded];", runtime)
        self.assertIn("_overlay.superview != container", runtime)
        self.assertIn("[container bringSubviewToFront:_overlay];", runtime)

    def test_screenshot_reasserts_persistent_menu_button(self) -> None:
        runtime = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn("UIApplicationUserDidTakeScreenshotNotification", runtime)
        self.assertIn("- (void)userDidTakeScreenshot:", runtime)
        handler = runtime.split("- (void)userDidTakeScreenshot:", 1)[1].split(
            "- (void)showMotionSteering", 1
        )[0]
        self.assertGreaterEqual(handler.count("reattachOverlayIfNeeded"), 2)
        self.assertIn("menuButton.hidden = NO;", runtime)
        self.assertIn("menuButton.alpha = 1.0;", runtime)


if __name__ == "__main__":
    unittest.main()
