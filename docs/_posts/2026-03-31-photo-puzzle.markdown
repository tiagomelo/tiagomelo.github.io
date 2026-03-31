---
layout: post
title:  "Photo Puzzle: turn your photos into jigsaw puzzles"
date:   2026-03-31 13:29:29 -0000
categories: opensource reactnative expo mobile ios
image: "/assets/images/2026-03-31-photo-puzzle/banner.png"
---

![banner](/assets/images/2026-03-31-photo-puzzle/banner.png)

I'm excited to announce that [Photo Puzzle](https://apps.apple.com/us/app/make-your-photo-puzzle/id6760949600) is now available on the App Store!

It's a mobile app that transforms your photos into interactive jigsaw puzzles. Pick any photo from your gallery or snap a new one with your camera, choose a difficulty level, and start solving.

I built it with [React Native](https://reactnative.dev/) and [Expo](https://expo.dev/).

<a href="https://apps.apple.com/us/app/make-your-photo-puzzle/id6760949600">
  <img src="/assets/images/2026-03-31-photo-puzzle/appstore-badge.svg" alt="Download on the App Store" width="200">
</a>

---

## features

* **Create puzzles from any photo** — use your gallery or take a new picture with the camera
* **5 difficulty levels** — from Easy (3×3) to Master (8×8)
* **Smooth animations with haptics** — pieces snap into place with satisfying feedback
* **Progress tracking** — track your time and number of moves
* **Hint system** — toggle piece numbers when you need a little help
* **Puzzle gallery** — save and revisit your puzzles
* **Pro upgrade** — unlock unlimited hints and remove ads

---

## screenshots

<!-- TODO: add screenshots -->

![screenshot 1](/assets/images/2026-03-31-photo-puzzle/screenshot1.webp)

![screenshot 2](/assets/images/2026-03-31-photo-puzzle/screenshot2.webp)

![screenshot 3](/assets/images/2026-03-31-photo-puzzle/screenshot3.webp)

![screenshot 4](/assets/images/2026-03-31-photo-puzzle/screenshot4.webp)

![screenshot 5](/assets/images/2026-03-31-photo-puzzle/screenshot5.webp)

![screenshot 6](/assets/images/2026-03-31-photo-puzzle/screenshot6.webp)

---

## how it works

When you select a photo, the app slices it into a grid of pieces based on your chosen difficulty. The pieces are then shuffled, and you drag them into position to reconstruct the original image.

Under the hood, it uses [React Native Gesture Handler](https://docs.swmansion.com/react-native-gesture-handler/) for smooth drag interactions and [React Native Reanimated](https://docs.swmansion.com/react-native-reanimated/) for performant animations that run on the native thread.

---

## tech stack

* [React Native](https://reactnative.dev/) + [Expo](https://expo.dev/)
* [React Native Gesture Handler](https://docs.swmansion.com/react-native-gesture-handler/) for drag interactions
* [React Native Reanimated](https://docs.swmansion.com/react-native-reanimated/) for animations
* [Expo Image Manipulator](https://docs.expo.dev/versions/latest/sdk/imagemanipulator/) for slicing photos into puzzle pieces
* [React Native IAP](https://react-native-iap.dooboolab.com/) for in-app purchases
* [Google Mobile Ads](https://docs.page/invertase/react-native-google-mobile-ads) for ad integration

---

## try it out

[Photo Puzzle](https://apps.apple.com/us/app/make-your-photo-puzzle/id6760949600) is free to download on the App Store. Give it a try and let me know what you think!
