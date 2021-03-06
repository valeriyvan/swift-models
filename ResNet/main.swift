import TensorFlow

let batchSize = 100

let (trainingDataset, testDataset) = loadCIFAR10()
let testBatches = testDataset.batched(Int64(batchSize))

// ResNet18, ResNet34, ResNet50, ResNet101, ResNet152
// PreActivatedResNet18, PreActivatedResNet34
var model = ResNet50(imageSize: 32, classCount: 10) // Use the network sized for CIFAR-10

// the classic ImageNet optimizer setting diverges on CIFAR-10
// let optimizer = SGD(for: model, learningRate: 0.1, momentum: 0.9, scalarType: Float.self)
let optimizer = SGD(for: model, learningRate: 0.001, scalarType: Float.self)

print("Starting training...")
for epoch in 1...10 {
    var trainingLossSum: Float = 0
    var trainingBatchCount = 0
    let trainingShuffled = trainingDataset.shuffled(sampleCount: 50000, randomSeed: Int64(epoch))
    for batch in trainingShuffled.batched(Int64(batchSize)) {
        let (labels, images) = (batch.first, batch.second)
        let (loss, gradients) = valueWithGradient(at: model) { model -> Tensor<Float> in
            let logits = model.applied(to: images, in: Context(learningPhase: .training))
            return softmaxCrossEntropy(logits: logits, labels: labels)
        }
        trainingLossSum += loss.scalarized()
        trainingBatchCount += 1
        optimizer.update(&model.allDifferentiableVariables, along: gradients)
    }
    var testLossSum: Float = 0
    var testBatchCount = 0
    var correctGuessCount = 0
    var totalGuessCount: Int32 = 0
    for batch in testBatches {
        let (labels, images) = (batch.first, batch.second)
        let logits = model.inferring(from: images)
        testLossSum += softmaxCrossEntropy(logits: logits, labels: labels).scalarized()
        testBatchCount += 1

        let correctPredictions = logits.argmax(squeezingAxis: 1) .== labels
        correctGuessCount = correctGuessCount +
            Int(Tensor<Int32>(correctPredictions).sum().scalarized())
        totalGuessCount = totalGuessCount + Int32(batchSize)
    }

    let accuracy = Float(correctGuessCount) / Float(totalGuessCount)
    print("""
          [Epoch \(epoch)] \
          Accuracy: \(correctGuessCount)/\(totalGuessCount) (\(accuracy)) \
          Loss: \(testLossSum / Float(testBatchCount))
          """)
}
