# UTIColonyCounting
Repo for UTIColonyCounting

This repository contains a xcode-project file and all required files and folders to modify and compile this proof of concept application. The UI is built using SwiftUI, some Apple frameworks and depends on Mijick Camera.

At the moment there is no functional storage of analysis outcomes.

The application is structured fairly straightforward. As expected in a SwiftUI app there is an App structure and a ContentView structure. Additionally there is a CoreML class for handling of machine learning tasks. The UI is linearly structured from the contentview, so you can read the content view file from top to bottom.

To prevent confusion; CoreML has a different coordinate system from swiftui. Thus for rendering the bounding boxes in the UI a conversion has to take place. This is done in ResultView by the functions convertSpace and invertConvertSpace. 

Currently manually removing annotations is not yet possible. As is exporting the annotations in conjunct with the captured image. 
