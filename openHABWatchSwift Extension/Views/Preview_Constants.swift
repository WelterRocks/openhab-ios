// Copyright (c) 2010-2020 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import Foundation

struct PreviewConstants {
    static let remoteURLString = "http://192.168.2.15:8081"

    static let sitemapJson = """
    {
        "id": "watch",
        "title": "watch",
        "link": "http://192.168.2.15:8081/rest/sitemaps/watch/watch",
        "leaf": true,
        "timeout": false,
        "widgets": [
            {
                "widgetId": "00",
                "type": "Switch",
                "visibility": true,
                "label": "Licht Keller WC Decke",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightSwitch6_1",
                    "state": "OFF",
                    "type": "Switch",
                    "name": "lcnLightSwitch6_1",
                    "label": "Licht Keller WC Decke",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "gKellerLicht",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "01",
                "type": "Switch",
                "visibility": true,
                "label": "Licht Oberlicht",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightSwitch14_1",
                    "state": "OFF",
                    "type": "Switch",
                    "name": "lcnLightSwitch14_1",
                    "label": "Licht Oberlicht",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "gEGLicht",
                        "G_PresenceSimulation",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "02",
                "type": "Switch",
                "visibility": true,
                "label": "Licht Esstisch",
                "icon": "switch",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightSwitch20_1",
                    "state": "ON",
                    "type": "Switch",
                    "name": "lcnLightSwitch20_1",
                    "label": "Licht Esstisch",
                    "tags": [],
                    "groupNames": [
                        "gEGLicht",
                        "G_PresenceSimulation",
                        "gLcn",
                        "gStateON"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "03",
                "type": "Slider",
                "visibility": true,
                "label": "Esstisch [100]",
                "icon": "slider",
                "mappings": [],
                "switchSupport": false,
                "sendFrequency": 0,
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnLightDimmer",
                    "state": "100",
                    "stateDescription": {
                        "pattern": "%s",
                        "readOnly": false,
                        "options": []
                    },
                    "type": "Dimmer",
                    "name": "lcnLightDimmer",
                    "label": "Esstisch",
                    "tags": [
                        "Lighting"
                    ],
                    "groupNames": [
                        "gEGLicht",
                        "gLcn"
                    ]
                },
                "widgets": []
            },
            {
                "widgetId": "04",
                "type": "Switch",
                "visibility": true,
                "label": "Fernsteuerung",
                "icon": "switch",
                "mappings": [
                    {
                        "command": "0",
                        "label": "Overwrite"
                    },
                    {
                        "command": "1",
                        "label": "Kalender"
                    },
                    {
                        "command": "2",
                        "label": "Automatik"
                    }
                ],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/Automatik",
                    "state": "ON",
                    "type": "String",
                    "name": "Automatik",
                    "tags": [],
                    "groupNames": []
                },
                "widgets": []
            },
            {
                "widgetId": "05",
                "type": "Switch",
                "visibility": true,
                "label": "Jalousie WZ SÃ¼d links",
                "icon": "rollershutter",
                "mappings": [],
                "item": {
                    "link": "http://192.168.2.15:8081/rest/items/lcnJalousieWZSuedLinks",
                    "state": "NULL",
                    "type": "Rollershutter",
                    "name": "lcnJalousieWZSuedLinks",
                    "label": "Jalousie WZ Süd links",
                    "tags": [],
                    "groupNames": [
                        "gWZ",
                        "gEGJalousien",
                        "gHausJalousie",
                        "gJalousienSued",
                        "gEGJalousienSued",
                        "gLcn"
                    ]
                },
                "widgets": []
            }
        ]
    }
    """.data(using: .utf8)!
}