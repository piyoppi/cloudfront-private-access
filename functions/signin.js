import crypto from 'crypto'
import fs from 'fs'
import path from 'path'
import querystring from 'querystring'
import { ApplicationConfig } from './.generated/configModule'

import { OAuth2Client } from 'google-auth-library'
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3'

const getObject = async (client, bucket, key) => {
  const response = await client.send(new GetObjectCommand({Bucket: bucket, Key: key}))
  const stream = response.Body
  
  return new Promise((resolve, reject) => {
    const chunks = []
    stream.on('data', chunk => chunks.push(chunk))
    stream.on('error', reject)
    stream.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')))
  })
}

const verifyIdToken = async (clientId, token) => {
  const client = new OAuth2Client(clientId)
  const ticket = await client.verifyIdToken({
    idToken: token,
    audience: clientId,
  })

  const payload = ticket.getPayload()

  return {
    uid: payload.email
  }
}

const buildPolicy = (url, expires) => {
  return {
    "Statement": [
      {
        "Resource": `${url}/*`,
        "Condition": {
          "DateLessThan": {
            "AWS:EpochTime": expires
          }
        }
      }
    ]
  }
}

const signPolicy = (policy, privateKey) => {
  const policyEncoded = Buffer.from(JSON.stringify(policy)).toString('base64')
  const signer = crypto.createSign('RSA-SHA1');
  signer.update(JSON.stringify(policy));
  const signature = signer.sign(privateKey, 'base64')
    .replace(/\+/g, '-')
    .replace(/=/g, '_')
    .replace(/\//g, '~')

  return {
    policyEncoded,
    signature
  }
}

export const signInHandler = async (event, context, callback) => {
  const expires = Math.floor(new Date().getTime() / 1000) + 600
  const request = event.Records[0].cf.request
  const body = Buffer.from(request.body.data, 'base64').toString()
  const params = querystring.parse(body)

  const configBucketName = ApplicationConfig.configBucketName
  const keyBucketRegion = 'us-east-1'
  const keyObjectKey = 'private_key.pem'
  const configObjectKey = 'config.json'
  const config = JSON.parse(await getObject(new S3Client({region: keyBucketRegion}), configBucketName, configObjectKey))
  const keyPairId = config.keyPairId
  const url = config.cloudFrontUrl
  const redirectUrl = url
  const clientId = config.authIssuerClientId

  try {
    const payload = await verifyIdToken(clientId, params.credential)

    if (!config.uid.includes(payload.uid)) {
      callback(null, {
        status: '404'
      })
      return
    }
  } catch(e) {
    callback(null, {
      status: '500'
    })
    throw new Error(e)
  }

  const privateKey = await getObject(new S3Client({region: keyBucketRegion}), configBucketName, keyObjectKey)
  const { policyEncoded, signature } = signPolicy(buildPolicy(url, expires), privateKey)

  const response = {
    status: '302',
    headers: {
      'location': [{
        key: 'Location',
        value: url,
      }],
      'set-cookie': [
        {
          key: 'Set-Cookie',
          value: `CloudFront-Policy=${policyEncoded}; Path=/; Secure; HttpOnly`
        },
        {
          key: 'Set-Cookie',
          value: `CloudFront-Signature=${signature}; Path=/; Secure; HttpOnly`
        },
        {
          key: 'Set-Cookie',
          value: `CloudFront-Key-Pair-Id=${keyPairId}; Path=/; Secure; HttpOnly`
        },
      ]
    },
  }

  callback(null, response)
}
