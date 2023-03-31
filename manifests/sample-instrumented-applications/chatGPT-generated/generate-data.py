import time

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from opentelemetry import metrics
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import SERVICE_NAME, Resource


from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from flask import Flask

# Initialize a Flask app
app = Flask(__name__)

# Instrument the Flask app with OpenTelemetry
FlaskInstrumentor().instrument_app(app)

resource = Resource(attributes={
    SERVICE_NAME: "otlpgenerate"
})

traceprovider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="localhost:4317"))
traceprovider.add_span_processor(processor)
trace.set_tracer_provider(traceprovider)

reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint="localhost:4317")
)
metricsprovider = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(metricsprovider)

# Define a counter metric
counter = metricsprovider.get_meter(__name__).create_counter(
    "requests",
    "Number of requests",
    "requests",
)

# Define a route for the Flask app
@app.route("/")
def hello():
    # Increment the counter metric
    counter.add(1)

    # Start a new span for the request
    with traceprovider.get_tracer(__name__).start_as_current_span("hello"):
        # Simulate a delay
        time.sleep(1)

    return "Hello, World!"

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
