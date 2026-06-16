pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: surface
    property real s: 1
    property var auth: null
    property string screenName: ""

    readonly property bool isMain: {
        var scr = Quickshell.screens;
        for (var i = 0; i < scr.length; i++)
            if (scr[i] && scr[i].name === "DP-1")
                return surface.screenName === "DP-1";
        return true;
    }

    readonly property real spread: 2.4
    readonly property size half: Qt.size(Math.max(2, Math.round(width / 2)), Math.max(2, Math.round(height / 2)))
    readonly property size quarter: Qt.size(Math.max(2, Math.round(width / 4)), Math.max(2, Math.round(height / 4)))
    readonly property size eighth: Qt.size(Math.max(2, Math.round(width / 8)), Math.max(2, Math.round(height / 8)))
    readonly property vector2d eighthVec: Qt.vector2d(eighth.width, eighth.height)

    clip: true

    Image {
        id: bgImg
        anchors.fill: parent
        source: {
            if (surface.screenName.length === 0)
                return "";
            var dir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
            return "file://" + dir + "/ricelin-lock-" + surface.screenName + ".png";
        }
        fillMode: Image.PreserveAspectCrop
        smooth: true
        cache: false
        visible: false
    }

    ShaderEffectSource {
        id: downHalf
        anchors.fill: parent
        sourceItem: bgImg
        textureSize: surface.half
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: copyHalf
        anchors.fill: parent
        visible: false
        property var source: downHalf
    }

    ShaderEffectSource {
        id: downQuarter
        anchors.fill: parent
        sourceItem: copyHalf
        textureSize: surface.quarter
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: copyQuarter
        anchors.fill: parent
        visible: false
        property var source: downQuarter
    }

    ShaderEffectSource {
        id: downEighth
        anchors.fill: parent
        sourceItem: copyQuarter
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: blurH1
        anchors.fill: parent
        visible: false
        property var source: downEighth
        property vector2d resolution: surface.eighthVec
        property vector2d blurDir: Qt.vector2d(1, 0)
        property real spread: surface.spread
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurH1Src
        anchors.fill: parent
        sourceItem: blurH1
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: blurV1
        anchors.fill: parent
        visible: false
        property var source: blurH1Src
        property vector2d resolution: surface.eighthVec
        property vector2d blurDir: Qt.vector2d(0, 1)
        property real spread: surface.spread
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurV1Src
        anchors.fill: parent
        sourceItem: blurV1
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: blurH2
        anchors.fill: parent
        visible: false
        property var source: blurV1Src
        property vector2d resolution: surface.eighthVec
        property vector2d blurDir: Qt.vector2d(1, 0)
        property real spread: surface.spread
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurH2Src
        anchors.fill: parent
        sourceItem: blurH2
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: blurV2
        anchors.fill: parent
        visible: false
        property var source: blurH2Src
        property vector2d resolution: surface.eighthVec
        property vector2d blurDir: Qt.vector2d(0, 1)
        property real spread: surface.spread
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurV2Src
        anchors.fill: parent
        sourceItem: blurV2
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: blurH3
        anchors.fill: parent
        visible: false
        property var source: blurV2Src
        property vector2d resolution: surface.eighthVec
        property vector2d blurDir: Qt.vector2d(1, 0)
        property real spread: surface.spread
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurH3Src
        anchors.fill: parent
        sourceItem: blurH3
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: blurV3
        anchors.fill: parent
        visible: false
        property var source: blurH3Src
        property vector2d resolution: surface.eighthVec
        property vector2d blurDir: Qt.vector2d(0, 1)
        property real spread: surface.spread
        fragmentShader: "shaders/blur.frag.qsb"
    }

    ShaderEffectSource {
        id: blurV3Src
        anchors.fill: parent
        sourceItem: blurV3
        textureSize: surface.eighth
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: blurV3Src
        property vector2d srcSize: surface.eighthVec
        property real darken: 0.62
        fragmentShader: "shaders/grade.frag.qsb"
    }

    GlowField {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.55
    }

    Content {
        id: content
        anchors.fill: parent
        s: surface.s
        auth: surface.auth
        isMain: surface.isMain
    }
}
