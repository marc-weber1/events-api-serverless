import dynamo from 'dynamodb';
import Joi from 'joi';
dynamo.AWS.config.update({accessKeyID: process.env.db_key_id, secretAccessKey: process.env.db_secret_key, region: process.env.aws_region})

var ExampleModel = dynamo.define('event_api_dynamo_example', {
	hashKey: 'key',

	schema: {
		key: Joi.string(),
		value: Joi.string()
	}
});
ExampleModel.config({tableName: process.env.db_name});

export default ExampleModel;