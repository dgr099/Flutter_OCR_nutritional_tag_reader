import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diacritic/diacritic.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _extractText = '';
  XFile? _pickedImage; //empleamos uint8list ya que file da errores en web
  bool _scanning = false;
  dynamic inputImage = null;
  String scannedText = "";
  int selectDict = 0;
  var busqSp = [
    "tamano",
    "trans",
    "mono",
    "poli",
    "sat",
    "gras",
    "carb",
    "fibr",
    "prot",
    "anadidos",
    "az",
    "sal",
    "col",
    "sodi",
  ];
  var busqEng = [
    "size",
    "trans",
    "mono",
    "poli",
    "sat",
    "fat",
    "carb",
    "fibe",
    "prot",
    "added",
    "suga",
    "salt",
    "chol",
    "sodi",
  ];
  //map string, valor
  var values = {};

  pickImage(ImageSource source) async {
    final ImagePicker _imagePicker = ImagePicker();
    XFile? _file = await _imagePicker.pickImage(source: source);
    if (_file != null) {
      //si seleccionó una imagen de forma correcta
      //no devolvemos file por el tema de dart.io que no es muy accesible en internet
      return await _file.readAsBytes();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: SingleChildScrollView(
        child: Column(children: [
          InkWell(
            onTap: () async {
              setState(() {
                _scanning = true;
              });
              //vaciamos los valores
              values = {};
              //_pickedImage = await pickImage(ImageSource.camera);
              _pickedImage =
                  await ImagePicker().pickImage(source: ImageSource.gallery);
              inputImage = InputImage.fromFilePath(_pickedImage!.path);
              setState(() {});
              final textDetector =
                  TextRecognizer(script: TextRecognitionScript.latin);
              ;
              RecognizedText recognisedText =
                  await textDetector.processImage(inputImage);
              await textDetector.close();
              scannedText = "";

              //buscamos números seguidos o no por paréntesis con o sin decimales
              //final regexAmount = RegExp(r'[0-9]*(\.|,)?[0-9]+\s*g');
              //este acepta la o como si fuera un 0
              final regexAmount =
                  RegExp(r'([0-9]|o)*(\.|,)?([0-9]|o)+\s*(g|mg)');
              //el número debe tener almenos un espacio para que no tome B1 como numero
              final regexNumb = RegExp(r'(^|\s)[0-9]*(\.|,)?[0-9]+');
              //cantidad aislada
              final regexSepAmountNumb =
                  RegExp(r'^\s*([0-9]|o)*(\.|,)?([0-9]|o)+\s*(g|mg)');
              final regexEnergy = RegExp(r'[0-9]*(\.|,)?[0-9]+\s*(kcal|cal)');
              //orden en que aparecen las claves
              var valors = [];
              //set con todos los números
              Set numbers = {};
              var dict = [];
              if (selectDict == 0) {
                dict = busqEng;
              } else {
                dict = busqSp;
              }
              for (TextBlock block in recognisedText.blocks) {
                for (TextLine line in block.lines) {
                  bool sflag = false;
                  String tex = removeDiacritics(line.text.toLowerCase());
                  scannedText = scannedText + line.text + "\n";

                  if (!values.keys.contains("kcal") &&
                      (tex.contains("energ") ||
                          tex.contains("cal") ||
                          tex.contains("kcal"))) {
                    if (regexEnergy.hasMatch(tex)) {
                      final match = regexEnergy.firstMatch(tex);
                      values["kcal"] = match!.group(0)!.replaceAll(" ", "");
                      numbers.add(values["kcal"]);
                      continue;
                    }
                  }

                  //si la linea contiene alguno de los valores que estamos buscando
                  //miramos a ver si tiene numeros

                  for (String val in dict) {
                    if (tex.contains(val)) {
                      if (values.keys.contains(val) || valors.contains(val)) {
                        break;
                      }
                      //comprobamos si el texto se refiere a porción
                      if (regexAmount.hasMatch(tex)) {
                        final match = regexAmount.firstMatch(tex);
                        values[val] = match!.group(0)!.replaceAll(" ", "");
                      } else
                        valors.add(val);
                      break;
                    }
                  }

                  //buscamos cantidad aislada
                  if (regexSepAmountNumb.hasMatch(tex)) {
                    for (var match in regexAmount.allMatches(tex)) {
                      var aux = match.group(0)!.replaceAll(" ", "");
                      numbers.add(aux);
                      if (valors.length > 0) {
                        var act = valors.removeAt(0);
                        values[act] = aux;
                      }
                    }
                  } else if (regexNumb.hasMatch(tex))
                    for (var match in regexNumb.allMatches(tex)) {
                      var aux = match.group(0)!.replaceAll(" ", "");
                      numbers.add(aux);
                      if (valors.length > 0) {
                        var act = valors.removeAt(0);
                        values[act] = aux;
                      }
                    }
                }
              }
              setState(() {
                _scanning = false;
              });
            },
            child: Text(
              "Select image",
              style: TextStyle(fontSize: 50),
            ),
          ),
          _pickedImage == null
              ? Container(
                  height: 300,
                  width: 300,
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.image,
                  ),
                )
              : Image.file(File(_pickedImage!.path)),
          Row(
            children: [
              Text("Idioma: "),
              DropdownButton(
                  value: selectDict,
                  items: [
                    DropdownMenuItem(
                      child: Text("English"),
                      value: 0,
                    ),
                    DropdownMenuItem(
                      child: Text("Spanish"),
                      value: 1,
                    )
                  ],
                  onChanged: ((value) {
                    setState(() {
                      selectDict = value!;
                    });
                  }))
            ],
          ),
          Text("Tabla:"),
          for (var key in values.keys) Text(key + ": " + values[key]),
          _scanning ? CircularProgressIndicator() : SizedBox(),
          Text("Texto completo escaneado: \n" + scannedText),
        ]),
      ),
    ));
  }
}
