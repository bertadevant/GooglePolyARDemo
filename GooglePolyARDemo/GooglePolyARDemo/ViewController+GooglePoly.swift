import UIKit
import SceneKit
import ARKit

extension ViewController {
    //MARK: Google POLY
    fileprivate func loadObjectToScene(nodePathURL: URL) {
        let modelAsset = MDLAsset(url: nodePathURL)
        modelAsset.loadTextures()
        let modelObject = modelAsset.object(at: 0)
        let node = SCNNode(mdlObject: modelObject)
        node.scale = SCNVector3Make(0.15, 0.15, 0.15)
        node.position = SCNVector3Make(0, -0.2, -0.8)
        let rotate = SCNAction.repeatForever(SCNAction.rotate(by: .pi, around: SCNVector3Make(0, 1, 0), duration: 3))
        node.runAction(rotate)
        sceneView.scene.rootNode.addChildNode(node)
    }

    fileprivate func downloadObjectsFromPoly() {
        let googleLoader = GooglePolyLoader()
        guard let url = googleLoader.urlForAsset(assetID: assetID) else {
            return
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)

        session.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
            guard let data = data else {
                print("error calling GET on /todos/1")
                print(error!)
                return
            }
            guard let asset = self?.parseData(data: data) else {
                return
            }

        })
    }

    private func parseData(data: Data) -> GooglePolyAsset? {
        let decoder = JSONDecoder()
        do {
            let asset = try decoder.decode(GooglePolyAsset.self, from: data)
            return asset
        } catch (let error) {
            print("parsing error \(error)")
            return nil
        }
    }

    private func mtlPathURLFrom(filePath: URL) -> URL? {
        guard filePath.pathExtension == "mtl" else {
            return nil
        }
        return filePath
    }
}

extension ARShowCaseViewController: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let urlRequest = downloadTask.originalRequest,
            let urlLastComponent = urlRequest.url?.lastPathComponent,
            let assetPathURL = pathForDownloadedObject(assetId: urlLastComponent) else {
                return
        }

        if assetExists(inPath: assetPathURL) {
            removeDuplicateFiles(assetUrl: assetPathURL)
        }

        moveDownloadedAsset(from: location, to: assetPathURL)

        guard let objectURL = filePathForObjectAsset(filePath: assetPathURL) else {
            return
        }
        loadObjectToScene(nodePathURL: objectURL)
    }

    private func pathForDownloadedObject(assetId: String ) -> URL?  {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                                      .userDomainMask,
                                                                      true).first else {
                                                                        return nil
        }
        return URL(fileURLWithPath: documentsPath).appendingPathComponent(assetId)
    }

    private func assetExists(inPath filePath: URL) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: filePath.absoluteString)
    }

    private func removeDuplicateFiles(assetUrl: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: assetUrl.absoluteString)
        } catch (let error) {
            print("Failed to delete file. \(error.localizedDescription)")
        }
    }

    private func moveDownloadedAsset(from currentLocation: URL, to filePath: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.moveItem(at: currentLocation, to: filePath)
        } catch (let error) {
            print("Failed to download file. \(error.localizedDescription)")
        }
    }

    private func filePathForObjectAsset(filePath: URL) -> URL? {
        guard filePath.lastPathComponent.contains("obj") else {
            return nil
        }
        return filePath
    }

    fileprivate func downloadFiles(fileURLs: [URL]) {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
        for url in fileURLs {
            let downloadTask = session.downloadTask(with: url)
            downloadTask.resume()
        }
    }
}
