This file explains structure of input device/board configuration JSON



{
        "uniqueName": "MUSCLESB",
        // Unique name for particular product. It is unique on the set of all BYB devices.


        "userFriendlyFullName":"Muscle SpikerBox Pro",
        "userFriendlyShortName":"Muscle SpikerBox Pro",

        "hardwareComProtocolType": "iap2,hid",
        // Can be "iap2", "hid", "serial" for now

        "bybProtocolType": "BYB1",
        //cyrrently we have only one protocol "BYB1" in future maybe we will have more

        "bybProtocolVersion": "1.0",

        "maxSampleRate":"10000",
        //maximal sample rate that device can produce at any configuration of channels. Some devices have lower sample rate when multiple channels are active

        "maxNumberOfChannels":"2",
        "defaultTimeScale":"0.1",
        "supportedPlatforms":"android,ios,win,mac,linux",
        "productURL":"https://backyardbrains.com/products/musclespikerboxpro",
        "helpURL":"https://backyardbrains.com/products/musclespikerboxpro",
        "iconURL":"",
        "firmwareUpdateUrl":"https://backyardbrains.com/products/firmwares/sbpro/compatibility.xml",
        "defaultGain":"1.0",
        "sampleRateIsFunctionOfNumberOfChannels":0,
        "miniOSAppVersion":"3.0.0",
        "minAndroidAppVersion":"1.0.0",
        "minWinAppVersion":"1.0.0",
        "minMacAppVersion":"1.0.0",
        "minLinuxAppVersion":"1.0.0",
        "hid":{
        "VID":"0x2E73",
        "PID":"0x1"
        },
        "filter":{
        "signalType":"emgSignal",
        "lowPassON":1,
        "lowPassCutoff":"2500.0",
        "highPassON":1,
        "highPassCutoff":"1.0",
        "notchFilterState":"notch60Hz"
        },
        "channels":[
        {
        "userFriendlyFullName":"EMG Channel 1",
        "userFriendlyShortName":"EMG Ch. 1",
        "activeByDefault":1,
        "filtered":1
        },
        {
        "userFriendlyFullName":"EMG Channel 2",
        "userFriendlyShortName":"EMG Ch. 2",
        "activeByDefault":0,
        "filtered":1
        }
        ],
        "expansionBoards":[
        {
        "boardType":"0",
        "userFriendlyFullName":"Default - events detection expansion board",
        "userFriendlyShortName":"Events detection",
        "supportedPlatforms":"android,ios,win,mac,linux",
        "maxNumberOfChannels":"0"
        },
        {
        "boardType":"1",
        "userFriendlyFullName":"Additional analog input channels",
        "userFriendlyShortName":"Analog x 2",
        "maxSampleRate":"5000",
        "supportedPlatforms":"android,ios,win,mac,linux",
        "productURL":"",
        "helpURL":"",
        "iconURL":"",
        "maxNumberOfChannels":"2",
        "defaultTimeScale":"0.1",
        "defaultGain":"1.0",
        "channels":[
        {
        "userFriendlyFullName":"EMG Channel 3",
        "userFriendlyShortName":"EMG Ch. 3",
        "activeByDefault":1,
        "filtered":0
        },
        {
        "userFriendlyFullName":"EMG Channel 4",
        "userFriendlyShortName":"EMG Ch. 4",
        "activeByDefault":0,
        "filtered":0
        }
        ]
        },
        {
        "boardType":"4",
        "userFriendlyFullName":"The Reflex Hammer",
        "userFriendlyShortName":"Hammer",
        "maxSampleRate":"5000",
        "maxNumberOfChannels":"1",
        "supportedPlatforms":"android,ios,win,mac,linux",
        "productURL":"https://backyardbrains.com/products/ReflexHammer",
        "helpURL":"https://backyardbrains.com/products/ReflexHammer",
        "iconURL":"",
        "defaultTimeScale":"0.1",
        "defaultGain":"1.0",
        "channels":[
        {
        "userFriendlyFullName":"Hammer channel",
        "userFriendlyShortName":"Hammer ch.",
        "activeByDefault":1,
        "filtered":0
        }
        ]
        },
        {
        "boardType":"5",
        "userFriendlyFullName":"The Joystick control",
        "userFriendlyShortName":"Joystick",
        "maxSampleRate":"5000",
        "maxNumberOfChannels":"1",
        "supportedPlatforms":"win",
        "productURL":"",
        "helpURL":"",
        "iconURL":"",
        "defaultTimeScale":"0.1",
        "defaultGain":"1.0",
        "channels":[
        {
        "userFriendlyFullName":"Joystick EMG channel",
        "userFriendlyShortName":"Joystick EMG",
        "activeByDefault":1,
        "filtered":0
        }
        ]
        }
        ]
},
