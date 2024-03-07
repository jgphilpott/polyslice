let device = {}

let history = []
let commandIndex = 0

let usbVendorId = null
let usbProductId = null

let baudRateDefault = 115200
let bufferSizeDefault = 1024
let dataBitsDefault = 8
let stopBitsDefault = 1
let flowControlDefault = "none"
let parityDefault = "none"

async function connect() {

    try {

        if (usbVendorId && usbProductId) {

            device = await navigator.serial.requestPort({
                filters: [{
                    usbVendorId: usbVendorId,
                    usbProductId: usbProductId
                }]
            })

        } else {

            device = await navigator.serial.requestPort()

        }

        let baudRate = Number($("#baud-rate").val())
        let bufferSize = Number($("#buffer-size").val())
        let dataBits = Number($("#data-bits").val())
        let stopBits = Number($("#stop-bits").val())
        let flowControl = String($("#flow-control").val())
        let parity = String($("#parity").val())

        await device.open({

            baudRate: baudRate,
            bufferSize: bufferSize,
            dataBits: dataBits,
            stopBits: stopBits,
            flowControl: flowControl,
            parity: parity

        })

        connected()

        read()

    } catch (error) {

        log("output", "<span class='error'>Failed to Connect</span>")

        console.log("Failed to connect with serial port: ", error)

    }

}

async function disconnect() {

    try {

        await device.forget()

        disconnected()

    } catch (error) {

        log("output", "<span class='error'>Failed to Disconnect</span>")

        console.log("Failed to disconnect with serial port: ", error)

    }

}

function connected() {

    device.connected = true

    let info = device.getInfo()

    usbVendorId = info.usbVendorId
    usbProductId = info.usbProductId

    $("button#connection").text("Disconnect")

    $("textarea#prompt").prop("disabled", false)

    $("button#connection").addClass("disconnect")
    $("button#connection").removeClass("connect")

    log("output", "<span class='success'>Connected</span>")

    console.log("Connected with: ", device)

    $("textarea#prompt").focus()

}

function disconnected() {

    device.connected = false

    $("button#connection").text("Connect")

    $("textarea#prompt").prop("disabled", true)

    $("button#connection").addClass("connect")
    $("button#connection").removeClass("disconnect")

    log("output", "<span class='error'>Disconnected</span>")

    console.log("Disconnected with: ", device)

    $("textarea#prompt").val("").change()
    $("textarea#prompt").attr("rows", 1)

}

async function read() {

    while (device.readable) {

        const decoder = new TextDecoder()
        const reader = device.readable.getReader()

        console.log("Started reading serial port.")

        try {

            while (true) {

                const {value, done} = await reader.read()

                let text = decoder.decode(value).replace("echo:", "").replace("\n", " ")

                text = text.replace("Unknown command:", "<span class='error'>Unknown command:</span>")
                text = text.replace("busy:", "<span class='info'>Busy:</span>")
                text = text.replace("ok", "<span class='success'>OK</span>")

                text = text.replace("X:", "<b class='x'>X:</b> ")
                text = text.replace("Y:", "<b class='y'>Y:</b> ")
                text = text.replace("Z:", "<b class='z'>Z:</b> ")
                text = text.replace("E:", "<b class='e'>E:</b> ")

                log("output", text)

                if (done) break

            }

        } catch (error) {

            console.log("Stopped reading serial port.")

        } finally {

            reader.releaseLock()

            break

        }

    }

}

async function write(text) {

    const encoder = new TextEncoder()
    const writer = device.writable.getWriter()

    await writer.write(encoder.encode(text))

    writer.releaseLock()

}

async function reset() {

    if (confirm("Are you sure you want to reset? This will clear your logs and restore all settings to their default values.")) {

        history = []
        commandIndex = 0

        localWrite("inputs", [])
        localWrite("outputs", [])
        localWrite("history", [])

        $("img#reset").rotate(360)

        if (device.connected) await disconnect()

        $("textarea#prompt").val("").change()
        $("textarea#prompt").attr("rows", 1)

        $("input#baud-rate").val(baudRateDefault)
        $("input#buffer-size").val(bufferSizeDefault)
        $("input#data-bits").val(dataBitsDefault)
        $("input#stop-bits").val(stopBitsDefault)
        $("select#flow-control").val(flowControlDefault)
        $("select#parity").val(parityDefault)

        localWrite("baudRate", baudRateDefault)
        localWrite("bufferSize", bufferSizeDefault)
        localWrite("dataBits", dataBitsDefault)
        localWrite("stopBits", stopBitsDefault)
        localWrite("flowControl", flowControlDefault)
        localWrite("parity", parityDefault)

        $("#output").empty()
        $("#input").empty()

    }

}

function log(zone, text) {

    time = "<span class='time'>" + new Date().toLocaleTimeString([], {hour12: false}) + "</span>"
    text = "<p>" + time + "<span class='pointer'> >>> </span>" + text + "</p>"

    let logs = localRead(zone + "s"); logs.push(text)

    $("#" + zone + "").append(text)

    let div = document.getElementById(zone)
    div.scrollTop = div.scrollHeight

    localWrite(zone + "s", logs)

}

document.addEventListener("DOMContentLoaded", (event) => {

    if (navigator.serial) {

        $("#compatible").css("display", "block")

        let baudRate = localRead("baudRate")
        let bufferSize = localRead("bufferSize")
        let dataBits = localRead("dataBits")
        let stopBits = localRead("stopBits")
        let flowControl = localRead("flowControl")
        let parity = localRead("parity")

        let inputs = localRead("inputs")
        let outputs = localRead("outputs")

        history = localRead("history")

        baudRate = baudRate != null ? baudRate : baudRateDefault
        bufferSize = bufferSize != null ? bufferSize : bufferSizeDefault
        dataBits = dataBits != null ? dataBits : dataBitsDefault
        stopBits = stopBits != null ? stopBits : stopBitsDefault
        flowControl = flowControl != null ? flowControl : flowControlDefault
        parity = parity != null ? parity : parityDefault

        inputs = inputs != null ? inputs : []
        outputs = outputs != null ? outputs : []
        history = history != null ? history : []

        localWrite("inputs", inputs)
        localWrite("outputs", outputs)

        inputs.forEach((input) => {
            $("#input").append(input)
        })

        outputs.forEach((output) => {
            $("#output").append(output)
        })

        let input = document.getElementById("input")
        let output = document.getElementById("output")

        input.scrollTop = input.scrollHeight
        output.scrollTop = output.scrollHeight

        if (typeof baudRate == "number" && baudRate > 0) {
            $("input#baud-rate").val(baudRate)
            localWrite("baudRate", baudRate)
        } else {
            $("input#baud-rate").val(baudRateDefault)
            localWrite("baudRate", baudRateDefault)
        }

        if (typeof bufferSize == "number" && bufferSize > 0) {
            $("input#buffer-size").val(bufferSize)
            localWrite("bufferSize", bufferSize)
        } else {
            $("input#buffer-size").val(bufferSizeDefault)
            localWrite("bufferSize", bufferSizeDefault)
        }

        if (typeof dataBits == "number" && (dataBits == 7 || dataBits == 8)) {
            $("input#data-bits").val(dataBits)
            localWrite("dataBits", dataBits)
        } else {
            $("input#data-bits").val(dataBitsDefault)
            localWrite("dataBits", dataBitsDefault)
        }

        if (typeof stopBits == "number" && (stopBits == 1 || stopBits == 2)) {
            $("input#stop-bits").val(stopBits)
            localWrite("stopBits", stopBits)
        } else {
            $("input#stop-bits").val(stopBitsDefault)
            localWrite("stopBits", stopBitsDefault)
        }

        if (["none", "hardware"].includes(flowControl)) {
            $("select#flow-control").val(flowControl)
            localWrite("flowControl", flowControl)
        } else {
            $("select#flow-control").val(flowControlDefault)
            localWrite("flowControl", flowControlDefault)
        }

        if (["none", "even", "odd"].includes(parity)) {
            $("select#parity").val(parity)
            localWrite("parity", parity)
        } else {
            $("select#parity").val(parityDefault)
            localWrite("parity", parityDefault)
        }

        navigator.serial.addEventListener("connect", (event) => {
            connected()
        })

        navigator.serial.addEventListener("disconnect", (event) => {
            disconnected()
        })

        $("img#reset").on("click", async (event) => { reset() })

        $("button#connection").on("click", async (event) => {
            if (device.connected) {
                disconnect()
            } else {
                connect()
            }
        })

        $("div#settings .control").on("change", async (event) => {

            if (device.connected) await disconnect()

            let setting = $(event.target).attr("name")
            let key = camelize($(event.target).attr("id"))

            let oldValue = localRead(key)
            let newValue = $(event.target).val()

            log("output", "<span class='info'>Connection Setting Changed</span>")
            log("output", "<b>" + setting + ":</b> " + oldValue + " > " + newValue + "")

            if ($(event.target).prop("type") == "number") {
                newValue = Number(newValue)
            } else {
                newValue = String(newValue)
            }

            localWrite(key, newValue)

        })

        $("textarea#prompt").on("keydown", async (event) => {

            let prompt = $(event.target).val().trim()

            if (event.key == "Enter" && !event.shiftKey) {

                commandIndex = 0

                event.preventDefault()

                if (prompt.length) {

                    history.unshift(prompt)

                    let text = prompt + "\n"

                    text.split("\n").forEach((command) => {

                        if (command.length) log("input", command)

                    })

                    localWrite("history", history)

                    write(text)

                }

                $(event.target).val("").change()
                $(event.target).attr("rows", 1)

            } else if (event.key == "Enter" && event.shiftKey) {

                let rows = Number($(event.target).attr("rows"))

                $(event.target).attr("rows", rows + 1)

            } else if ((event.key == "ArrowUp" || event.key == "ArrowDown") && history.length) {

                let cursor = Number($(event.target).prop("selectionStart"))
                let size = Number($(event.target).val().length)

                if (event.key == "ArrowUp" && cursor == 0) {

                    commandIndex += 1

                    if (commandIndex > history.length) commandIndex = history.length

                    $(event.target).attr("rows", history[commandIndex - 1].split("\n").length)
                    $(event.target).val(history[commandIndex - 1])

                }

                if (event.key == "ArrowDown" && cursor == size) {

                    commandIndex -= 1

                    if (commandIndex < 0) commandIndex = 0

                    if (commandIndex) {

                        $(event.target).attr("rows", history[commandIndex - 1].split("\n").length)
                        $(event.target).val(history[commandIndex - 1])

                    } else {

                        $(event.target).val("").change()
                        $(event.target).attr("rows", 1)

                    }

                }

            }

        })

    } else {

        $("#incompatible").css("display", "block")

    }

})

$(window).on("focus", (event) => {
    if (device.connected) {
        $("textarea#prompt").focus()
    }
})

window.onbeforeunload = (event) => {
    if (device.connected) {
        disconnect()
    }
}