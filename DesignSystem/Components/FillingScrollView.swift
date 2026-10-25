//
//  FillingScrollView.swift
//  BeerStats
//
//  Ein Scroll-Bereich, dessen Inhalt den Bildschirm AUSFUELLT und mittig
//  steht, solange er hineinpasst – und erst scrollt, wenn er es nicht mehr
//  tut.
//
//  Siebzehn Screens standen als `ScrollView { VStack { … } }` im Projekt,
//  und ein ScrollView legt seinen Inhalt nach OBEN. Bei langem Inhalt faellt
//  das nicht auf; bei kurzem – der Spion in der Vorbereitung, Schocken
//  zwischen zwei Wuerfen, der Sieger-Screen – klebte alles am oberen Rand
//  und die untere Haelfte des Geraets blieb leer. Auf einem grossen iPhone
//  sieht das aus wie ein halb geladener Screen.
//
//  Das ist dieselbe Sache wie „Freier Platz ist kein Design" vom
//  17. Oktober, nur eine Ebene hoeher: Dort wuchsen die Karten INNERHALB
//  eines Screens in den freien Raum, hier wird der Screen selbst gefuellt.
//
//  Die Loesung steht bewusst in EINEM Baustein und nicht siebzehnmal an der
//  Aufrufstelle. Sie besteht aus zwei Teilen, die zusammengehoeren – ein
//  `GeometryReader` fuer die verfuegbare Hoehe und ein `minHeight` darauf –,
//  und `maxHeight: .infinity` allein hilft nicht: Ohne eine bestimmte Hoehe
//  hat es nichts, in das es wachsen koennte. Wer das an jeder Stelle neu
//  tippt, tippt es irgendwo nur halb.
//
//  Benutzt wird er wie ein `ScrollView` – an der Aufrufstelle steht nur ein
//  anderer Name.
//

import SwiftUI

struct FillingScrollView<Content: View>: View {

    /// Woran der Inhalt ausgerichtet wird, wenn Platz uebrig ist. Mittig ist
    /// die Vorgabe; Listen, die von oben gelesen werden, geben `.top` an und
    /// gewinnen dann nur das Ausfuellen in der Breite.
    var alignment: Alignment = .center

    /// Gespeicherte Closure und kein Funktionsparameter: Nur dadurch darf
    /// sie in den `GeometryReader`, dessen Closure escaping ist (siehe
    /// Lessons Learned Nr. 13 in CLAUDE.md).
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content()
                    // Mindestens so hoch und breit wie der Platz, den es
                    // gibt. Mehr darf es werden – dann scrollt es wieder,
                    // genau wie vorher.
                    .frame(
                        minWidth: geometry.size.width,
                        minHeight: geometry.size.height,
                        alignment: alignment
                    )
            }
            .verticalScrollOnly()
        }
    }
}
